# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::RedCandle::Tools do
  describe ".candle_tool_for" do
    let(:fake_candle_tool) { double("CandleTool", name: "test") }

    before do
      # Candle::Tool may not exist in test env (native extension)
      stub_const("Candle::Tool", Class.new) unless defined?(Candle::Tool)
      allow(Candle::Tool).to receive(:new).and_return(fake_candle_tool)
    end

    it "uses params_schema when available" do
      schema = { type: "object", properties: { city: { type: "string" } }, required: ["city"] }
      tool = double("Tool", name: "get_weather", description: "Gets weather", params_schema: schema, parameters: [])

      described_class.candle_tool_for(tool)

      expect(::Candle::Tool).to have_received(:new).with(
        name: "get_weather",
        description: "Gets weather",
        parameters: schema
      )
    end

    it "falls back to SchemaDefinition when params_schema is nil" do
      fallback_schema = { type: "object", properties: {}, required: [] }
      tool = double("Tool", name: "search", description: "Searches", params_schema: nil, parameters: [])
      schema_def = double("SchemaDefinition", json_schema: fallback_schema)
      allow(RubyLLM::Tool::SchemaDefinition).to receive(:from_parameters).and_return(schema_def)

      described_class.candle_tool_for(tool)

      expect(::Candle::Tool).to have_received(:new).with(
        name: "search",
        description: "Searches",
        parameters: fallback_schema
      )
    end

    it "uses empty schema when both params_schema and SchemaDefinition return nil" do
      tool = double("Tool", name: "noop", description: "No-op", params_schema: nil, parameters: [])
      allow(RubyLLM::Tool::SchemaDefinition).to receive(:from_parameters).and_return(nil)

      described_class.candle_tool_for(tool)

      expect(::Candle::Tool).to have_received(:new).with(
        name: "noop",
        description: "No-op",
        parameters: { type: "object", properties: {}, required: [] }
      )
    end

    it "handles nil description by defaulting to empty string" do
      tool = double("Tool", name: "test", description: nil,
                     params_schema: { type: "object", properties: {}, required: [] }, parameters: [])

      described_class.candle_tool_for(tool)

      expect(::Candle::Tool).to have_received(:new).with(
        hash_including(description: "")
      )
    end
  end

  describe ".parse_tool_calls" do
    it "returns nil for nil input" do
      expect(described_class.parse_tool_calls(nil)).to be_nil
    end

    it "returns nil for empty array" do
      expect(described_class.parse_tool_calls([])).to be_nil
    end

    it "converts candle tool calls to RubyLLM format" do
      candle_tc = double("ToolCall", name: "get_weather", arguments: { "city" => "Paris" })
      result = described_class.parse_tool_calls([candle_tc])

      expect(result).to be_a(Hash)
      expect(result.size).to eq(1)

      call = result.values.first
      expect(call).to be_a(RubyLLM::ToolCall)
      expect(call.name).to eq("get_weather")
      expect(call.arguments).to eq({ "city" => "Paris" })
    end
  end

  describe ".format_tool_call" do
    it "formats an assistant message with tool calls" do
      tool_call = RubyLLM::ToolCall.new(id: "call_1", name: "get_weather", arguments: { "city" => "Paris" })
      msg = double("Message", content: "Let me check", tool_calls: { "call_1" => tool_call })

      result = described_class.format_tool_call(msg)

      expect(result[:role]).to eq("assistant")
      expect(result[:content]).to include("get_weather")
      expect(result[:content]).to include("<tool_call>")
    end
  end

  describe ".format_tool_result" do
    it "formats a tool result message" do
      msg = double("Message", content: '{"temperature": 72}')
      result = described_class.format_tool_result(msg)

      expect(result[:role]).to eq("tool")
      expect(result[:content]).to eq('{"temperature": 72}')
    end
  end
end
