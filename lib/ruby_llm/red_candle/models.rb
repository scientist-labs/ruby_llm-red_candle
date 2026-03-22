# frozen_string_literal: true

module RubyLLM
  module RedCandle
    # Models methods of the RedCandle integration
    module Models
      # TODO: red-candle supports more models, but let's start with some well tested ones.
      SUPPORTED_MODELS = [
        # Mistral
        {
          id: "TheBloke/Mistral-7B-Instruct-v0.2-GGUF",
          name: "Mistral 7B Instruct v0.2 (Quantized)",
          gguf_file: "mistral-7b-instruct-v0.2.Q4_K_M.gguf",
          tokenizer: "mistralai/Mistral-7B-Instruct-v0.2",
          context_window: 32_768,
          family: "mistral",
          supports_chat: true,
          supports_structured: true
        },
        {
          id: "MaziyarPanahi/Mistral-7B-Instruct-v0.3-GGUF",
          name: "Mistral 7B Instruct v0.3 (Quantized)",
          gguf_file: "Mistral-7B-Instruct-v0.3.Q4_K_M.gguf",
          tokenizer: "mistralai/Mistral-7B-Instruct-v0.3",
          context_window: 32_768,
          family: "mistral",
          supports_chat: true,
          supports_structured: true
        },
        # Llama / TinyLlama
        {
          id: "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
          name: "TinyLlama 1.1B Chat",
          context_window: 2048,
          family: "llama",
          supports_chat: true,
          supports_structured: true
        },
        {
          id: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
          name: "TinyLlama 1.1B Chat (Quantized)",
          gguf_file: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
          context_window: 2048,
          family: "llama",
          supports_chat: true,
          supports_structured: true
        },
        # Gemma
        {
          id: "google/gemma-3-4b-it-qat-q4_0-gguf",
          name: "Gemma 3 4B Instruct (Quantized)",
          gguf_file: "gemma-3-4b-it-q4_0.gguf",
          tokenizer: "google/gemma-3-4b-it",
          context_window: 8192,
          family: "gemma",
          supports_chat: true,
          supports_structured: true
        },
        # Qwen 2.5
        {
          id: "Qwen/Qwen2.5-1.5B-Instruct-GGUF",
          name: "Qwen 2.5 1.5B Instruct (Quantized)",
          gguf_file: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
          context_window: 32_768,
          family: "qwen2",
          supports_chat: true,
          supports_structured: true
        },
        # Qwen 3
        {
          id: "Qwen/Qwen3-0.6B",
          name: "Qwen3 0.6B",
          context_window: 40_960,
          family: "qwen3",
          supports_chat: true,
          supports_structured: true,
          supports_tools: true
        },
        {
          id: "MaziyarPanahi/Qwen3-0.6B-GGUF",
          name: "Qwen3 0.6B (Quantized)",
          gguf_file: "Qwen3-0.6B.Q4_K_M.gguf",
          tokenizer: "Qwen/Qwen3-0.6B",
          context_window: 40_960,
          family: "qwen3",
          supports_chat: true,
          supports_structured: true,
          supports_tools: true
        },
        {
          id: "MaziyarPanahi/Qwen3-4B-GGUF",
          name: "Qwen3 4B (Quantized)",
          gguf_file: "Qwen3-4B.Q4_K_M.gguf",
          tokenizer: "Qwen/Qwen3-4B",
          context_window: 40_960,
          family: "qwen3",
          supports_chat: true,
          supports_structured: true,
          supports_tools: true
        },
        # SmolLM2
        {
          id: "HuggingFaceTB/SmolLM2-360M-Instruct",
          name: "SmolLM2 360M Instruct",
          context_window: 8192,
          family: "llama",
          supports_chat: true,
          supports_structured: true
        },
        {
          id: "HuggingFaceTB/SmolLM2-360M-Instruct-GGUF",
          name: "SmolLM2 360M Instruct (Quantized)",
          gguf_file: "smollm2-360m-instruct-q8_0.gguf",
          context_window: 8192,
          family: "llama",
          supports_chat: true,
          supports_structured: true
        },
        # Phi
        {
          id: "microsoft/phi-2",
          name: "Phi 2",
          context_window: 2048,
          family: "phi",
          supports_chat: true,
          supports_structured: true
        },
        {
          id: "TheBloke/phi-2-GGUF",
          name: "Phi 2 (Quantized)",
          gguf_file: "phi-2.Q4_K_M.gguf",
          context_window: 2048,
          family: "phi",
          supports_chat: true,
          supports_structured: true
        },
        {
          id: "microsoft/Phi-3-mini-4k-instruct",
          name: "Phi 3 Mini 4K Instruct",
          context_window: 4096,
          family: "phi",
          supports_chat: true,
          supports_structured: true
        },
        {
          id: "microsoft/Phi-3-mini-4k-instruct-gguf",
          name: "Phi 3 Mini 4K Instruct (Quantized)",
          gguf_file: "Phi-3-mini-4k-instruct-q4.gguf",
          context_window: 4096,
          family: "phi",
          supports_chat: true,
          supports_structured: true
        },
        {
          id: "microsoft/phi-4-gguf",
          name: "Phi 4 (Quantized)",
          gguf_file: "phi-4-Q4_K_S.gguf",
          context_window: 16_384,
          family: "phi",
          supports_chat: true,
          supports_structured: true
        },
        # Yi
        {
          id: "bartowski/Yi-1.5-6B-Chat-GGUF",
          name: "Yi 1.5 6B Chat (Quantized)",
          gguf_file: "Yi-1.5-6B-Chat-Q4_K_M.gguf",
          tokenizer: "01-ai/Yi-1.5-6B-Chat",
          context_window: 4096,
          family: "llama",
          supports_chat: true,
          supports_structured: true
        },
        # Granite
        {
          id: "ibm-granite/granite-7b-instruct",
          name: "Granite 7B Instruct",
          context_window: 4096,
          family: "granite",
          supports_chat: true,
          supports_structured: true
        },
        {
          id: "ibm-granite/granite-4.0-micro",
          name: "Granite 4.0 Micro",
          context_window: 8192,
          family: "granite",
          supports_chat: true,
          supports_structured: true
        },
        # GLM-4
        {
          id: "bartowski/THUDM_GLM-4-9B-0414-GGUF",
          name: "GLM-4 9B (Quantized)",
          gguf_file: "THUDM_GLM-4-9B-0414-Q4_K_M.gguf",
          tokenizer: "THUDM/GLM-4-9B-0414",
          context_window: 131_072,
          family: "glm4",
          supports_chat: true,
          supports_structured: true
        },
      ].freeze

      def list_models
        SUPPORTED_MODELS.map do |model_data|
          RubyLLM::Model::Info.new(
            id: model_data[:id],
            name: model_data[:name],
            provider: slug,
            family: model_data[:family],
            context_window: model_data[:context_window],
            capabilities: %w[streaming structured_output],
            modalities: { input: %w[text], output: %w[text] }
          )
        end
      end

      def models
        @models ||= list_models
      end

      def model(id)
        models.find { |m| m.id == id } ||
          raise(RubyLLM::Error.new(nil,
                                   "Model #{id} not found in Red Candle provider. " \
                                   "Available models: #{model_ids.join(', ')}"))
      end

      def model_available?(id)
        SUPPORTED_MODELS.any? { |m| m[:id] == id }
      end

      def model_ids
        SUPPORTED_MODELS.map { |m| m[:id] }
      end

      def model_info(id)
        SUPPORTED_MODELS.find { |m| m[:id] == id }
      end

      def supports_chat?(model_id)
        info = model_info(model_id)
        info ? info[:supports_chat] : false
      end

      def supports_structured?(model_id)
        info = model_info(model_id)
        info ? info[:supports_structured] : false
      end

      def gguf_file_for(model_id)
        info = model_info(model_id)
        info ? info[:gguf_file] : nil
      end

      def tokenizer_for(model_id)
        info = model_info(model_id)
        info ? info[:tokenizer] : nil
      end
    end
  end
end
