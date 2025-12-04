# frozen_string_literal: true

require "candle"

module RubyLLM
  module RedCandle
    # Red Candle provider for local LLM execution using the Candle Rust crate.
    class Provider < RubyLLM::Provider
      include Chat
      include Models
      include Capabilities
      include Streaming

      def initialize(config)
        ensure_red_candle_available!
        super
        @loaded_models = {} # Cache for loaded models
        @device = determine_device(config)
      end

      def api_base
        nil # Local execution, no API base needed
      end

      def headers
        {} # No HTTP headers needed
      end

      class << self
        def capabilities
          Capabilities
        end

        def configuration_requirements
          [] # No required config, device is optional
        end

        def local?
          true
        end

        def supports_functions?(model_id = nil)
          Capabilities.supports_functions?(model_id)
        end

        def models
          # Return Red Candle models for registration
          Models::SUPPORTED_MODELS.map do |model_data|
            RubyLLM::Model::Info.new(
              id: model_data[:id],
              name: model_data[:name],
              provider: "red_candle",
              type: "chat",
              family: model_data[:family],
              context_window: model_data[:context_window],
              capabilities: %w[streaming structured_output],
              modalities: { input: %w[text], output: %w[text] }
            )
          end
        end
      end

      private

      def ensure_red_candle_available!
        require "candle"
      rescue LoadError
        raise RubyLLM::Error.new(nil, "Red Candle gem is not installed. Add 'gem \"red-candle\"' to your Gemfile.")
      end

      def determine_device(config)
        if config.respond_to?(:red_candle_device) && config.red_candle_device
          case config.red_candle_device.to_s.downcase
          when "cpu"
            ::Candle::Device.cpu
          when "cuda", "gpu"
            ::Candle::Device.cuda
          when "metal"
            ::Candle::Device.metal
          else
            ::Candle::Device.best
          end
        else
          ::Candle::Device.best
        end
      rescue StandardError => e
        RubyLLM.logger.warn "Failed to initialize device: #{e.message}. Falling back to CPU."
        ::Candle::Device.cpu
      end
    end
  end
end
