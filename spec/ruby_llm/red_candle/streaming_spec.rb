# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::RedCandle::Streaming do
  let(:config) { RubyLLM::Configuration.new }
  let(:provider) { RubyLLM::RedCandle::Provider.new(config) }
  let(:mock_model) { instance_double(Candle::LLM) }

  before do
    allow(provider).to receive(:ensure_model_loaded!).and_return(mock_model)
    allow(mock_model).to receive(:respond_to?).with(:apply_chat_template).and_return(true)
    allow(mock_model).to receive(:apply_chat_template).and_return("formatted prompt")
  end

  describe "#stream" do
    let(:messages) { [{ role: "user", content: "Test message" }] }

    context "when stream: true" do
      it "calls perform_streaming_completion!" do
        tokens = %w[Hello world]

        allow(mock_model).to receive(:generate_stream) do |_prompt, config:, &block|
          tokens.each { |token| block.call(token) }
        end

        payload = {
          messages: messages,
          model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
          temperature: 0.7,
          stream: true
        }

        chunks = []
        provider.stream(payload) { |chunk| chunks << chunk }

        # Should receive token chunks plus final empty chunk
        expect(chunks.size).to eq(3)
        expect(chunks[0].content).to eq("Hello")
        expect(chunks[1].content).to eq("world")
        expect(chunks[2].content).to eq("")
      end
    end

    context "when stream: false" do
      it "yields a single chunk with complete result" do
        allow(mock_model).to receive(:generate).and_return("Complete response")

        payload = {
          messages: messages,
          model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
          temperature: 0.7,
          stream: false
        }

        chunks = []
        provider.stream(payload) { |chunk| chunks << chunk }

        expect(chunks.size).to eq(1)
        expect(chunks[0][:content]).to eq("Complete response")
        expect(chunks[0][:role]).to eq("assistant")
      end
    end

    context "when stream is nil (defaults to non-streaming)" do
      it "yields a single chunk with complete result" do
        allow(mock_model).to receive(:generate).and_return("Complete response")

        payload = {
          messages: messages,
          model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
          temperature: 0.7
        }

        chunks = []
        provider.stream(payload) { |chunk| chunks << chunk }

        expect(chunks.size).to eq(1)
        expect(chunks[0][:content]).to eq("Complete response")
      end
    end
  end

  describe "#stream_processor" do
    it "returns nil for compatibility" do
      expect(provider.send(:stream_processor)).to be_nil
    end
  end

  describe "#process_stream_response" do
    it "returns the response unchanged" do
      response = { content: "test" }
      expect(provider.send(:process_stream_response, response)).to eq(response)
    end
  end
end
