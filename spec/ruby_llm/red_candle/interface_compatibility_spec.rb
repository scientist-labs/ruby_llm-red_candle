# frozen_string_literal: true

require "spec_helper"

# These specs verify that the upstream APIs (red-candle gem and ruby_llm)
# still expose the classes and methods this plugin depends on.
# Unlike the rest of the test suite, nothing here is mocked — if an
# upstream gem changes its public interface, these tests fail immediately.

RSpec.describe "Interface compatibility" do
  describe "red-candle API" do
    describe Candle::LLM do
      it "responds to .from_pretrained" do
        expect(described_class).to respond_to(:from_pretrained),
          "Candle::LLM.from_pretrained is missing — red-candle API may have changed"
      end
    end

    describe Candle::Device do
      it "responds to .cpu" do
        expect(described_class).to respond_to(:cpu),
          "Candle::Device.cpu is missing — red-candle API may have changed"
      end

      it "responds to .best" do
        expect(described_class).to respond_to(:best),
          "Candle::Device.best is missing — red-candle API may have changed"
      end
    end

    describe Candle::GenerationConfig do
      it "is defined" do
        expect(defined?(Candle::GenerationConfig)).to eq("constant"),
          "Candle::GenerationConfig is not defined — red-candle API may have changed"
      end

      it "responds to .balanced" do
        expect(described_class).to respond_to(:balanced),
          "Candle::GenerationConfig.balanced is missing — red-candle API may have changed. " \
          "This class method is called in Chat#build_generation_config"
      end
    end

    describe "Candle::Tokenizer" do
      it "is defined" do
        expect(defined?(Candle::Tokenizer)).to eq("constant"),
          "Candle::Tokenizer is not defined — red-candle API may have changed"
      end
    end
  end

  describe "ruby_llm provider contract" do
    describe RubyLLM::RedCandle::Provider do
      it "inherits from RubyLLM::Provider" do
        expect(described_class).to be < RubyLLM::Provider,
          "RubyLLM::RedCandle::Provider no longer inherits from RubyLLM::Provider"
      end

      it "includes Chat module providing #complete" do
        expect(described_class.instance_methods).to include(:complete),
          "Provider is missing #complete — Chat module may not be included or ruby_llm interface changed"
      end

      it "includes Streaming module providing #stream" do
        expect(described_class.instance_methods).to include(:stream),
          "Provider is missing #stream — Streaming module may not be included or ruby_llm interface changed"
      end

      it "includes Models module providing #list_models" do
        expect(described_class.instance_methods).to include(:list_models),
          "Provider is missing #list_models — Models module may not be included or ruby_llm interface changed"
      end
    end

    describe RubyLLM::Message do
      it "can be instantiated with role, content, model_id, input_tokens, output_tokens" do
        msg = described_class.new(
          role: :assistant,
          content: "test",
          model_id: "test-model",
          input_tokens: 10,
          output_tokens: 5
        )
        expect(msg.role).to eq(:assistant)
        expect(msg.content).to eq("test")
      end
    end

    describe RubyLLM::Chunk do
      it "can be instantiated with role and content" do
        chunk = described_class.new(role: :assistant, content: "token")
        expect(chunk.role).to eq(:assistant)
        expect(chunk.content).to eq("token")
      end
    end

    describe RubyLLM::Model::Info do
      it "accepts the keyword args used by the plugin" do
        info = described_class.new(
          id: "test/model",
          name: "Test Model",
          provider: "red_candle",
          type: "chat",
          family: "test",
          context_window: 4096,
          capabilities: %w[streaming structured_output],
          modalities: { input: %w[text], output: %w[text] }
        )
        expect(info.id).to eq("test/model")
      end
    end
  end
end
