# frozen_string_literal: true

require "ruby_llm"

require_relative "ruby_llm/red_candle/version"
require_relative "ruby_llm/red_candle/capabilities"
require_relative "ruby_llm/red_candle/models"
require_relative "ruby_llm/red_candle/streaming"
require_relative "ruby_llm/red_candle/chat"
require_relative "ruby_llm/red_candle/provider"

module RubyLLM
  # Red Candle plugin module - provides local LLM execution using quantized GGUF models
  module RedCandle
    class << self
      # Register the provider with RubyLLM
      def register!
        RubyLLM::Provider.register :red_candle, Provider

        # Register Red Candle models with the global registry
        Provider.models.each do |model|
          RubyLLM.models.instance_variable_get(:@models) << model
        end
      end
    end
  end
end

# Auto-register when the gem is loaded
RubyLLM::RedCandle.register!
