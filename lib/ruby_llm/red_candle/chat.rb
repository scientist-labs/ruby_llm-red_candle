# frozen_string_literal: true

module RubyLLM
  module RedCandle
    # Chat implementation for Red Candle provider
    module Chat
      # Override the base complete method to handle local execution
      def complete(messages, tools:, temperature:, model:, params: {}, headers: {}, schema: nil, tool_prefs: nil, thinking: nil, &block)
        _ = headers # Interface compatibility
        _ = tool_prefs # Interface compatibility (not yet used by local models)
        _ = thinking # Interface compatibility (not yet used by local models)
        payload = RubyLLM::Utils.deep_merge(
          render_payload(
            messages,
            tools: tools,
            temperature: temperature,
            model: model,
            stream: block_given?,
            schema: schema
          ),
          params
        )

        if block_given?
          perform_streaming_completion!(payload, &block)
        else
          result = perform_completion!(payload)

          # perform_tool_completion! returns a Message directly
          return result if result.is_a?(RubyLLM::Message)

          # Convert hash result to Message object
          content = result[:content]
          estimated_output_tokens = (content.to_s.length / 4.0).round
          estimated_input_tokens = estimate_input_tokens(payload[:messages])

          RubyLLM::Message.new(
            role: result[:role].to_sym,
            content: content,
            model_id: model.id,
            input_tokens: estimated_input_tokens,
            output_tokens: estimated_output_tokens
          )
        end
      end

      def render_payload(messages, tools:, temperature:, model:, stream:, schema:, tool_prefs: nil, thinking: nil)
        payload = {
          messages: messages,
          temperature: temperature,
          model: model.id,
          stream: stream,
          schema: schema
        }

        if tools && !tools.empty?
          payload[:tools] = tools
        end

        payload
      end

      def perform_completion!(payload)
        model = ensure_model_loaded!(payload[:model])
        messages = format_messages(payload[:messages])

        # Handle tool calling
        if payload[:tools] && !payload[:tools].empty?
          return perform_tool_completion!(model, messages, payload)
        end

        # Handle structured generation differently - we need to build the prompt
        # with JSON instructions BEFORE applying the chat template
        response = if payload[:schema]
                     generate_with_schema(model, messages, payload[:schema], payload)
                   else
                     prompt = build_prompt(model, messages)
                     validate_context_length!(prompt, payload[:model])
                     config = build_generation_config(payload)
                     generate_with_error_handling(model, prompt, config, payload[:model])
                   end

        format_response(response, payload[:schema])
      end

      def perform_streaming_completion!(payload, &block)
        model = ensure_model_loaded!(payload[:model])
        messages = format_messages(payload[:messages])

        prompt = build_prompt(model, messages)
        validate_context_length!(prompt, payload[:model])
        config = build_generation_config(payload)

        # Collect all streamed content
        full_content = ""

        # Stream tokens with error handling
        stream_with_error_handling(model, prompt, config, payload[:model]) do |token|
          full_content += token
          chunk = format_stream_chunk(token)
          block.call(chunk)
        end

        # Send final chunk with empty content (indicates completion)
        final_chunk = format_stream_chunk("")
        block.call(final_chunk)

        # Return a Message object with the complete response
        estimated_output_tokens = (full_content.length / 4.0).round
        estimated_input_tokens = estimate_input_tokens(payload[:messages])

        RubyLLM::Message.new(
          role: :assistant,
          content: full_content,
          model_id: payload[:model],
          input_tokens: estimated_input_tokens,
          output_tokens: estimated_output_tokens
        )
      end

      private

      def perform_tool_completion!(model, messages, payload)
        # Convert RubyLLM tools to Candle tools
        candle_tools = payload[:tools].values.map { |t| Tools.candle_tool_for(t) }

        # Build generation config with enough room for thinking + tool calls
        # Tool calling needs more tokens than regular chat (model uses <think> blocks)
        payload[:max_tokens] ||= 1000
        config = build_generation_config(payload)

        # Use red-candle's chat_with_tools (execute: false — RubyLLM manages execution)
        result = model.chat_with_tools(messages, tools: candle_tools, config: config)

        content = result.text_response || ""
        tool_calls = Tools.parse_tool_calls(result.tool_calls)

        estimated_output_tokens = ((result.raw_response || "").length / 4.0).round
        estimated_input_tokens = estimate_input_tokens(payload[:messages])

        RubyLLM::Message.new(
          role: :assistant,
          content: content.empty? ? nil : content,
          tool_calls: tool_calls,
          model_id: payload[:model],
          input_tokens: estimated_input_tokens,
          output_tokens: estimated_output_tokens
        )
      end

      # Build the prompt string from messages using the model's chat template
      def build_prompt(model, messages)
        if model.respond_to?(:apply_chat_template)
          model.apply_chat_template(messages)
        else
          # Fallback to simple formatting
          "#{messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n\n")}\n\nassistant:"
        end
      end

      # Get generation parameters with consistent defaults
      # @param payload [Hash] The request payload
      # @param structured [Boolean] Whether this is for structured generation (uses different defaults)
      # @return [Array<Float, Integer>] temperature and max_length values
      def generation_params(payload, structured: false)
        temperature = payload[:temperature] || (structured ? 0.3 : 0.7)
        max_length = payload[:max_tokens] || (structured ? 1024 : 512)
        [temperature, max_length]
      end

      # Build generation config with consistent defaults
      # @param payload [Hash] The request payload
      # @param structured [Boolean] Whether this is for structured generation (uses different defaults)
      def build_generation_config(payload, structured: false)
        temperature, max_length = generation_params(payload, structured: structured)
        ::Candle::GenerationConfig.balanced(
          temperature: temperature,
          max_length: max_length
        )
      end

      def ensure_model_loaded!(model_id)
        @loaded_models[model_id] ||= load_model(model_id)
      end

      def model_options(model_id)
        # Get GGUF file and tokenizer if this is a GGUF model
        # Access the methods from the Models module which is included in the provider
        options = { device: @device }
        options[:gguf_file] = gguf_file_for(model_id) if respond_to?(:gguf_file_for)
        options[:tokenizer] = tokenizer_for(model_id) if respond_to?(:tokenizer_for)
        options
      end

      def load_model(model_id)
        options = model_options(model_id)
        ::Candle::LLM.from_pretrained(model_id, **options)
      rescue StandardError => e
        if e.message.include?("Failed to find tokenizer")
          raise RubyLLM::Error.new(nil, token_error_message(e, options[:tokenizer]))
        elsif e.message.include?("Failed to find model")
          raise RubyLLM::Error.new(nil, model_error_message(e, model_id))
        else
          raise RubyLLM::Error.new(nil, "Failed to load model #{model_id}: #{e.message}")
        end
      end

      def token_error_message(exception, tokenizer)
        <<~ERROR_MESSAGE
          Failed to load tokenizer '#{tokenizer}'. The tokenizer may not exist or require authentication.
          Please verify the tokenizer exists at: https://huggingface.co/#{tokenizer}
          And that you have accepted the terms of service for the tokenizer.
          If it requires authentication, login with: huggingface-cli login
          See https://github.com/scientist-labs/red-candle?tab=readme-ov-file#%EF%B8%8F-huggingface-login-warning
          Original error: #{exception.message}"
        ERROR_MESSAGE
      end

      def model_error_message(exception, model_id)
        <<~ERROR_MESSAGE
          Failed to load model #{model_id}: #{exception.message}
          Please verify the model exists at: https://huggingface.co/#{model_id}
          And that you have accepted the terms of service for the model.
          If it requires authentication, login with: huggingface-cli login
          See https://github.com/scientist-labs/red-candle?tab=readme-ov-file#%EF%B8%8F-huggingface-login-warning
          Original error: #{exception.message}"
        ERROR_MESSAGE
      end

      def generate_with_error_handling(model, prompt, config, model_id)
        model.generate(prompt, config: config)
      rescue StandardError => e
        raise RubyLLM::Error.new(nil, generation_error_message(e, model_id))
      end

      def stream_with_error_handling(model, prompt, config, model_id, &block)
        model.generate_stream(prompt, config: config, &block)
      rescue StandardError => e
        raise RubyLLM::Error.new(nil, generation_error_message(e, model_id))
      end

      def generation_error_message(exception, model_id)
        message = exception.message.to_s

        if message.include?("out of memory") || message.include?("OOM")
          <<~ERROR_MESSAGE.strip
            Out of memory while generating with #{model_id}.
            Try using a smaller model or reducing the context length.
            Original error: #{message}
          ERROR_MESSAGE
        elsif message.include?("context") || message.include?("sequence")
          <<~ERROR_MESSAGE.strip
            Context length exceeded for #{model_id}.
            The input is too long for this model's context window.
            Original error: #{message}
          ERROR_MESSAGE
        elsif message.include?("tensor") || message.include?("shape")
          <<~ERROR_MESSAGE.strip
            Model execution error for #{model_id}.
            This may indicate an incompatible model format or corrupted weights.
            Original error: #{message}
          ERROR_MESSAGE
        else
          "Generation failed for #{model_id}: #{message}"
        end
      end

      def format_messages(messages)
        messages.map do |msg|
          if msg.is_a?(RubyLLM::Message)
            if msg.tool_call?
              Tools.format_tool_call(msg)
            elsif msg.tool_result?
              Tools.format_tool_result(msg)
            else
              {
                role: msg.role.to_s,
                content: extract_message_content_from_object(msg)
              }
            end
          else
            {
              role: msg[:role].to_s,
              content: extract_message_content(msg)
            }
          end
        end
      end

      def extract_message_content_from_object(message)
        content = message.content

        # Handle Content objects
        if content.is_a?(RubyLLM::Content)
          # Extract text from Content object, including attachment text
          handle_content_object(content)
        elsif content.is_a?(String)
          content
        else
          content.to_s
        end
      end

      def extract_message_content(message)
        content = message[:content]

        # Handle Content objects
        case content
        when RubyLLM::Content
          # Extract text from Content object
          handle_content_object(content)
        when String
          content
        when Array
          # Handle array content (e.g., with images)
          content.filter_map { |part| part[:text] if part[:type] == "text" }.join(" ")
        else
          content.to_s
        end
      end

      def handle_content_object(content)
        text_parts = []
        text_parts << content.text if content.text

        # Add any text from attachments
        content.attachments&.each do |attachment|
          text_parts << attachment.data if attachment.respond_to?(:data) && attachment.data.is_a?(String)
        end

        text_parts.join(" ")
      end

      def generate_with_schema(model, messages, schema, payload)
        # Use Red Candle's native structured generation which uses the Rust outlines crate
        # for grammar-constrained generation. This ensures valid JSON output.

        # Unwrap RubyLLM's schema wrapper format: {name: "response", schema: {...}, strict: true}
        actual_schema = schema.is_a?(Hash) && (schema[:schema] || schema["schema"]) ? (schema[:schema] || schema["schema"]) : schema

        # Normalize schema to ensure consistent symbol keys
        normalized_schema = deep_symbolize_keys(actual_schema)

        # Validate schema before attempting generation
        SchemaValidator.validate!(normalized_schema)

        # Debug logging to help diagnose issues
        RubyLLM.logger.debug "=== STRUCTURED GENERATION DEBUG ==="
        RubyLLM.logger.debug "Original schema: #{schema.inspect}"
        RubyLLM.logger.debug "Normalized schema: #{normalized_schema.inspect}"
        RubyLLM.logger.debug "Messages: #{messages.inspect}"

        # For structured generation, we modify the last user message to include
        # JSON output instructions, then apply the chat template
        structured_messages = build_structured_messages(messages, normalized_schema)
        RubyLLM.logger.debug "Structured messages: #{structured_messages.inspect}"

        prompt = build_prompt(model, structured_messages)
        RubyLLM.logger.debug "Final prompt:\n#{prompt}"
        RubyLLM.logger.debug "=== END DEBUG ==="

        validate_context_length!(prompt, payload[:model])

        # Get generation parameters (structured generation uses different defaults)
        temperature, max_length = generation_params(payload, structured: true)

        result = model.generate_structured(
          prompt,
          schema: normalized_schema,
          temperature: temperature,
          max_length: max_length,
          warn_on_parse_error: true,
          reset_cache: true
        )

        RubyLLM.logger.debug "Structured generation result: #{result.inspect}"

        # generate_structured returns a Hash on success, or raw String on parse failure
        result
      rescue StandardError => e
        # Log at debug level - the raised exception will inform the caller
        RubyLLM.logger.debug "Structured generation failed: #{e.class}: #{e.message}"
        RubyLLM.logger.debug e.backtrace.first(5).join("\n") if e.backtrace
        raise RubyLLM::Error.new(nil, "Structured generation failed: #{e.message}")
      end

      # Recursively convert all hash keys to symbols
      def deep_symbolize_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            result[key.to_sym] = deep_symbolize_keys(value)
          end
        when Array
          obj.map { |item| deep_symbolize_keys(item) }
        else
          obj
        end
      end

      def build_structured_messages(messages, schema)
        # Clone messages to avoid modifying the original
        modified_messages = messages.map(&:dup)

        # Find the last user message and append JSON instructions
        last_user_idx = modified_messages.rindex { |m| m[:role] == "user" }
        return modified_messages unless last_user_idx

        schema_description = describe_schema(schema)
        json_instruction = Configuration.build_json_instruction(schema_description)

        modified_messages[last_user_idx][:content] += json_instruction
        modified_messages
      end

      def describe_schema(schema)
        return "the requested data" unless schema.is_a?(Hash)

        # Support both symbol and string keys for robustness
        properties = schema[:properties] || schema["properties"]
        return "the requested data" unless properties

        properties.map do |key, value|
          type = value[:type] || value["type"] || "any"
          enum = value[:enum] || value["enum"]
          if enum
            "#{key} (#{type}, one of: #{enum.join(', ')})"
          else
            "#{key} (#{type})"
          end
        end.join(", ")
      end

      def format_response(response, schema)
        content = if schema && !response.is_a?(String)
                    # Structured response
                    JSON.generate(response)
                  else
                    response
                  end

        {
          content: content,
          role: "assistant"
        }
      end

      def format_stream_chunk(token)
        # Return a Chunk object for streaming compatibility
        RubyLLM::Chunk.new(
          role: :assistant,
          content: token
        )
      end

      def estimate_input_tokens(messages)
        # Rough estimation: ~4 characters per token
        formatted = format_messages(messages)
        total_chars = formatted.sum { |msg| "#{msg[:role]}: #{msg[:content]}".length }
        (total_chars / 4.0).round
      end

      def validate_context_length!(prompt, model_id)
        # Get the context window for this model
        context_window = if respond_to?(:model_context_window)
                           model_context_window(model_id)
                         else
                           4096 # Conservative default
                         end

        # Estimate tokens in prompt (~4 characters per token)
        estimated_tokens = (prompt.length / 4.0).round

        # Check if prompt exceeds context window (leave some room for response)
        max_input_tokens = context_window - 512 # Reserve 512 tokens for response
        return unless estimated_tokens > max_input_tokens

        raise RubyLLM::Error.new(
          nil,
          "Context length exceeded. Estimated #{estimated_tokens} tokens, " \
          "but model #{model_id} has a context window of #{context_window} tokens."
        )
      end

      # Delegate to Capabilities module for context window lookup
      def model_context_window(model_id)
        Capabilities.model_context_window(model_id)
      end
    end
  end
end
