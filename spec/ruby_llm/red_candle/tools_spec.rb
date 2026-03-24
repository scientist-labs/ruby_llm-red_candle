# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::RedCandle::Tools do
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
