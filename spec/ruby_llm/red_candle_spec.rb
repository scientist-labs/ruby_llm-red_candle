# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::RedCandle do
  describe "VERSION" do
    it "has a version number" do
      expect(RubyLLM::RedCandle::VERSION).not_to be_nil
    end
  end

  describe ".register!" do
    it "registers the provider with RubyLLM" do
      # The provider should already be registered from loading the gem
      expect(RubyLLM::Provider.providers).to have_key(:red_candle)
    end

    it "registers models with the global registry" do
      # Check that Red Candle models are in the global registry
      red_candle_models = RubyLLM.models.all.select { |m| m.provider == "red_candle" }
      expect(red_candle_models).not_to be_empty
    end
  end

  describe "integration with RubyLLM.chat" do
    it "can create a chat with red_candle provider" do
      chat = RubyLLM.chat(
        provider: :red_candle,
        model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF"
      )
      expect(chat).to be_a(RubyLLM::Chat)
    end

    it "can ask a question" do
      chat = RubyLLM.chat(
        provider: :red_candle,
        model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF"
      )
      response = chat.ask("What is 2 + 2?")
      expect(response).to be_a(RubyLLM::Message)
      expect(response.content).to be_a(String)
      expect(response.content).not_to be_empty
    end

    it "supports streaming" do
      chat = RubyLLM.chat(
        provider: :red_candle,
        model: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF"
      )

      chunks = []
      response = chat.ask("Count from 1 to 3") do |chunk|
        chunks << chunk
      end

      expect(chunks).not_to be_empty
      expect(chunks.first).to be_a(RubyLLM::Chunk)
      expect(response).to be_a(RubyLLM::Message)
    end
  end
end
