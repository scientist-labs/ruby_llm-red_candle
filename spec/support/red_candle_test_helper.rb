# frozen_string_literal: true

require_relative "mock_candle_model"

module RedCandleTestHelper
  def stub_red_candle_models!
    # Only stub if we're testing Red Candle
    return unless defined?(::Candle)

    # Stub the model loading to return our mock
    allow(::Candle::LLM).to receive(:from_pretrained) do |model_id, **_options|
      MockCandleModel.new(model_id)
    end
  end

  def unstub_red_candle_models!
    return unless defined?(::Candle)

    # Remove the stub if needed
    RSpec::Mocks.space.proxy_for(::Candle::LLM)&.reset
  end
end

RSpec.configure do |config|
  config.include RedCandleTestHelper

  # Automatically stub Red Candle models for all tests unless real inference requested
  config.before do |example|
    next if ENV["RED_CANDLE_REAL_INFERENCE"] == "true"
    next if example.metadata[:real_inference]

    stub_red_candle_models! if defined?(RubyLLM::RedCandle::Provider)
  end

  config.before(:suite) do
    if ENV["RED_CANDLE_REAL_INFERENCE"] == "true"
      puts "\n Red Candle: Using REAL inference (this will be slow)"
      puts "   To use mocked responses, unset RED_CANDLE_REAL_INFERENCE\n\n"
    else
      puts "\n Red Candle: Using MOCKED responses (fast)"
      puts "   To use real inference, set RED_CANDLE_REAL_INFERENCE=true\n\n"
    end
  end
end
