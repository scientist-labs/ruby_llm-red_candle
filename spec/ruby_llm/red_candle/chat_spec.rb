# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::RedCandle::Chat do
  let(:config) { RubyLLM::Configuration.new }
  let(:provider) { RubyLLM::RedCandle::Provider.new(config) }
  let(:model) { provider.model("TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF") }

  describe "#render_payload" do
    let(:messages) { [{ role: "user", content: "Hello" }] }

    it "creates a valid payload" do
      payload = provider.render_payload(
        messages,
        tools: nil,
        temperature: 0.7,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload).to include(
        messages: messages,
        temperature: 0.7,
        model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
        stream: false,
        schema: nil
      )
    end

    it "raises error when tools are provided" do
      tools = [{ name: "calculator", description: "Does math" }]

      expect do
        provider.render_payload(
          messages,
          tools: tools,
          temperature: 0.7,
          model: model,
          stream: false,
          schema: nil
        )
      end.to raise_error(RubyLLM::Error, /does not support tool calling/)
    end

    it "includes schema when provided" do
      schema = { type: "object", properties: { name: { type: "string" } } }

      payload = provider.render_payload(
        messages,
        tools: nil,
        temperature: 0.7,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:schema]).to eq(schema)
    end
  end

  describe "#perform_completion!" do
    let(:messages) { [{ role: "user", content: "Test message" }] }
    let(:mock_model) { instance_double(Candle::LLM) }

    before do
      allow(provider).to receive(:ensure_model_loaded!).and_return(mock_model)
      allow(mock_model).to receive(:respond_to?).with(:apply_chat_template).and_return(true)
      allow(mock_model).to receive(:apply_chat_template).and_return("formatted prompt")
    end

    context "with regular generation" do
      it "generates a response" do
        allow(mock_model).to receive(:generate).and_return("Generated response")

        payload = {
          messages: messages,
          model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
          temperature: 0.7
        }

        result = provider.perform_completion!(payload)

        expect(result).to include(
          content: "Generated response",
          role: "assistant"
        )
      end
    end

    context "with structured generation" do
      it "generates structured output" do
        schema = { type: "object", properties: { name: { type: "string" } } }
        structured_response = { "name" => "Alice" }

        allow(mock_model).to receive(:generate_structured).and_return(structured_response)

        payload = {
          messages: messages,
          model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
          temperature: 0.7,
          schema: schema
        }

        result = provider.perform_completion!(payload)

        expect(result[:content]).to eq(JSON.generate(structured_response))
        expect(result[:role]).to eq("assistant")
      end

      it "raises an error on structured generation failure" do
        schema = { type: "object", properties: { name: { type: "string" } } }

        allow(mock_model).to receive(:generate_structured).and_raise(StandardError, "Structured gen failed")
        allow(RubyLLM.logger).to receive(:error)

        payload = {
          messages: messages,
          model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
          temperature: 0.7,
          schema: schema
        }

        expect { provider.perform_completion!(payload) }.to raise_error(
          RubyLLM::Error,
          /Structured generation failed/
        )
        expect(RubyLLM.logger).to have_received(:error).at_least(:once)
      end

      it "normalizes schema keys to symbols" do
        # Test with string keys - should be normalized to symbols
        schema = { "type" => "object", "properties" => { "name" => { "type" => "string" } } }
        structured_response = { "name" => "Alice" }

        allow(mock_model).to receive(:generate_structured).and_return(structured_response)

        payload = {
          messages: messages,
          model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
          temperature: 0.7,
          schema: schema
        }

        result = provider.perform_completion!(payload)

        expect(result[:content]).to eq(JSON.generate(structured_response))
      end
    end
  end

  describe "#perform_streaming_completion!" do
    let(:messages) { [{ role: "user", content: "Stream test" }] }
    let(:mock_model) { instance_double(Candle::LLM) }

    before do
      allow(provider).to receive(:ensure_model_loaded!).and_return(mock_model)
      allow(mock_model).to receive(:respond_to?).with(:apply_chat_template).and_return(true)
      allow(mock_model).to receive(:apply_chat_template).and_return("formatted prompt")
    end

    it "streams tokens and sends finish reason" do
      tokens = %w[Hello world !]
      chunks_received = []

      allow(mock_model).to receive(:generate_stream) do |_prompt, config:, &block|
        tokens.each { |token| block.call(token) }
      end

      payload = {
        messages: messages,
        model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
        temperature: 0.7
      }

      provider.perform_streaming_completion!(payload) do |chunk|
        chunks_received << chunk
      end

      # Check token chunks
      tokens.each_with_index do |token, i|
        chunk = chunks_received[i]
        expect(chunk).to be_a(RubyLLM::Chunk)
        expect(chunk.content).to eq(token)
      end

      # Check final chunk (empty content indicates completion)
      final_chunk = chunks_received.last
      expect(final_chunk).to be_a(RubyLLM::Chunk)
      expect(final_chunk.content).to eq("")
    end
  end

  describe "message formatting" do
    it "handles string content" do
      messages = [{ role: "user", content: "Simple text" }]
      formatted = provider.send(:format_messages, messages)

      expect(formatted).to eq([{ role: "user", content: "Simple text" }])
    end

    it "handles array content with text parts" do
      messages = [{
        role: "user",
        content: [
          { type: "text", text: "Part 1" },
          { type: "text", text: "Part 2" },
          { type: "image", url: "ignored.jpg" }
        ]
      }]

      formatted = provider.send(:format_messages, messages)
      expect(formatted).to eq([{ role: "user", content: "Part 1 Part 2" }])
    end
  end

  describe "#deep_symbolize_keys" do
    it "converts string keys to symbols" do
      input = { "type" => "object", "properties" => { "name" => { "type" => "string" } } }
      result = provider.send(:deep_symbolize_keys, input)

      expect(result).to eq({ type: "object", properties: { name: { type: "string" } } })
    end

    it "handles arrays with hashes" do
      input = { "items" => [{ "name" => "Alice" }, { "name" => "Bob" }] }
      result = provider.send(:deep_symbolize_keys, input)

      expect(result).to eq({ items: [{ name: "Alice" }, { name: "Bob" }] })
    end

    it "preserves non-hash values" do
      input = { "count" => 42, "active" => true, "name" => "test" }
      result = provider.send(:deep_symbolize_keys, input)

      expect(result).to eq({ count: 42, active: true, name: "test" })
    end

    it "handles already symbolized keys" do
      input = { type: "object", properties: { name: { type: "string" } } }
      result = provider.send(:deep_symbolize_keys, input)

      expect(result).to eq(input)
    end
  end

  describe "#describe_schema" do
    it "returns description for schema with symbol keys" do
      schema = {
        type: "object",
        properties: {
          name: { type: "string" },
          age: { type: "integer" }
        }
      }

      result = provider.send(:describe_schema, schema)

      expect(result).to include("name (string)")
      expect(result).to include("age (integer)")
    end

    it "returns description for schema with string keys" do
      schema = {
        "type" => "object",
        "properties" => {
          "name" => { "type" => "string" },
          "age" => { "type" => "integer" }
        }
      }

      result = provider.send(:describe_schema, schema)

      expect(result).to include("name (string)")
      expect(result).to include("age (integer)")
    end

    it "handles enum values" do
      schema = {
        type: "object",
        properties: {
          status: { type: "string", enum: %w[active inactive] }
        }
      }

      result = provider.send(:describe_schema, schema)

      expect(result).to include("status (string, one of: active, inactive)")
    end

    it "returns fallback for invalid schema" do
      expect(provider.send(:describe_schema, nil)).to eq("the requested data")
      expect(provider.send(:describe_schema, "not a hash")).to eq("the requested data")
      expect(provider.send(:describe_schema, { type: "object" })).to eq("the requested data")
    end
  end

  describe "#build_structured_messages" do
    it "appends JSON instructions to the last user message" do
      messages = [
        { role: "user", content: "Hello" },
        { role: "assistant", content: "Hi there" },
        { role: "user", content: "Tell me about Ruby" }
      ]
      schema = { type: "object", properties: { answer: { type: "string" } } }

      result = provider.send(:build_structured_messages, messages, schema)

      expect(result.last[:content]).to include("Tell me about Ruby")
      expect(result.last[:content]).to include("Respond with ONLY a valid JSON object")
      expect(result.last[:content]).to include("answer (string)")
    end

    it "does not modify the original messages" do
      messages = [{ role: "user", content: "Original content" }]
      schema = { type: "object", properties: { test: { type: "string" } } }

      provider.send(:build_structured_messages, messages, schema)

      expect(messages.first[:content]).to eq("Original content")
    end

    it "returns unchanged messages when no user message exists" do
      messages = [{ role: "system", content: "System prompt" }]
      schema = { type: "object", properties: { test: { type: "string" } } }

      result = provider.send(:build_structured_messages, messages, schema)

      expect(result).to eq(messages)
    end
  end

  describe "#format_response" do
    it "converts hash response to JSON string when schema present" do
      response = { name: "Alice", age: 30 }
      result = provider.send(:format_response, response, { type: "object" })

      expect(result[:content]).to eq('{"name":"Alice","age":30}')
      expect(result[:role]).to eq("assistant")
    end

    it "returns string response as-is when schema present but response is string" do
      response = "Plain text response"
      result = provider.send(:format_response, response, { type: "object" })

      expect(result[:content]).to eq("Plain text response")
    end

    it "returns string response as-is when no schema" do
      response = "Plain text response"
      result = provider.send(:format_response, response, nil)

      expect(result[:content]).to eq("Plain text response")
    end
  end

  describe "#build_prompt" do
    let(:mock_model) { instance_double(Candle::LLM) }
    let(:messages) { [{ role: "user", content: "Hello" }] }

    it "uses chat template when model supports it" do
      allow(mock_model).to receive(:respond_to?).with(:apply_chat_template).and_return(true)
      allow(mock_model).to receive(:apply_chat_template).with(messages).and_return("<|user|>Hello<|assistant|>")

      result = provider.send(:build_prompt, mock_model, messages)

      expect(result).to eq("<|user|>Hello<|assistant|>")
    end

    it "uses fallback formatting when model does not support chat template" do
      allow(mock_model).to receive(:respond_to?).with(:apply_chat_template).and_return(false)

      result = provider.send(:build_prompt, mock_model, messages)

      expect(result).to eq("user: Hello\n\nassistant:")
    end

    it "handles multiple messages in fallback format" do
      multi_messages = [
        { role: "user", content: "Hi" },
        { role: "assistant", content: "Hello!" },
        { role: "user", content: "How are you?" }
      ]
      allow(mock_model).to receive(:respond_to?).with(:apply_chat_template).and_return(false)

      result = provider.send(:build_prompt, mock_model, multi_messages)

      expect(result).to eq("user: Hi\n\nassistant: Hello!\n\nuser: How are you?\n\nassistant:")
    end
  end

  describe "#generation_params" do
    it "returns default values for regular generation" do
      payload = {}
      temperature, max_length = provider.send(:generation_params, payload)

      expect(temperature).to eq(0.7)
      expect(max_length).to eq(512)
    end

    it "returns structured defaults when structured: true" do
      payload = {}
      temperature, max_length = provider.send(:generation_params, payload, structured: true)

      expect(temperature).to eq(0.3)
      expect(max_length).to eq(1024)
    end

    it "uses payload values when provided" do
      payload = { temperature: 0.5, max_tokens: 256 }
      temperature, max_length = provider.send(:generation_params, payload)

      expect(temperature).to eq(0.5)
      expect(max_length).to eq(256)
    end

    it "uses payload values over structured defaults" do
      payload = { temperature: 0.9, max_tokens: 2048 }
      temperature, max_length = provider.send(:generation_params, payload, structured: true)

      expect(temperature).to eq(0.9)
      expect(max_length).to eq(2048)
    end
  end

  describe "#build_generation_config" do
    it "returns a GenerationConfig with default values" do
      payload = {}
      config = provider.send(:build_generation_config, payload)

      expect(config).to be_a(Candle::GenerationConfig)
    end

    it "passes structured flag to generation_params" do
      payload = {}

      # Test that structured generation uses different defaults
      regular_config = provider.send(:build_generation_config, payload, structured: false)
      structured_config = provider.send(:build_generation_config, payload, structured: true)

      # Both should return valid configs
      expect(regular_config).to be_a(Candle::GenerationConfig)
      expect(structured_config).to be_a(Candle::GenerationConfig)
    end
  end
end
