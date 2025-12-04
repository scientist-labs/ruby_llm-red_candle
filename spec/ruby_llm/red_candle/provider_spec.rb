# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::RedCandle::Provider do
  let(:config) { RubyLLM::Configuration.new }
  let(:provider) { described_class.new(config) }

  describe "#initialize" do
    context "with device configuration" do
      it "uses the configured device" do
        allow(config).to receive(:respond_to?).with(:red_candle_device).and_return(true)
        allow(config).to receive(:red_candle_device).and_return("cpu")
        provider = described_class.new(config)
        expect(provider.instance_variable_get(:@device)).to eq(Candle::Device.cpu)
      end

      it "defaults to best device when not configured" do
        allow(config).to receive(:respond_to?).with(:red_candle_device).and_return(false)
        provider = described_class.new(config)
        expect(provider.instance_variable_get(:@device)).to eq(Candle::Device.best)
      end
    end
  end

  describe "#api_base" do
    it "returns nil for local execution" do
      expect(provider.api_base).to be_nil
    end
  end

  describe "#headers" do
    it "returns empty hash" do
      expect(provider.headers).to eq({})
    end
  end

  describe ".local?" do
    it "returns true" do
      expect(described_class.local?).to be true
    end
  end

  describe ".configuration_requirements" do
    it "returns empty array" do
      expect(described_class.configuration_requirements).to eq([])
    end
  end

  describe ".capabilities" do
    it "returns the Capabilities module" do
      expect(described_class.capabilities).to eq(RubyLLM::RedCandle::Capabilities)
    end
  end

  describe ".models" do
    it "returns an array of Model::Info objects" do
      models = described_class.models
      expect(models).to be_an(Array)
      expect(models).not_to be_empty
      expect(models.first).to be_a(RubyLLM::Model::Info)
    end

    it "sets provider to red_candle" do
      models = described_class.models
      models.each do |model|
        expect(model.provider).to eq("red_candle")
      end
    end
  end

  describe ".supports_functions?" do
    it "returns false" do
      expect(described_class.supports_functions?).to be false
    end
  end
end
