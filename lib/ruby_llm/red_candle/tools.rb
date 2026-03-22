# frozen_string_literal: true

require "securerandom"

module RubyLLM
  module RedCandle
    # Tool calling support for Red Candle provider.
    # Bridges between RubyLLM::Tool and Candle::Tool formats.
    module Tools
      module_function

      # Convert a RubyLLM::Tool to a Candle::Tool (without a callable block —
      # RubyLLM manages tool execution itself)
      def candle_tool_for(tool)
        parameters = tool.params_schema ||
                     RubyLLM::Tool::SchemaDefinition.from_parameters(tool.parameters)&.json_schema ||
                     { type: "object", properties: {}, required: [] }

        ::Candle::Tool.new(
          name: tool.name,
          description: tool.description || "",
          parameters: parameters
        ) { |_args| nil } # No-op block — RubyLLM handles execution
      end

      # Convert Candle::ToolCall objects to RubyLLM tool_calls hash format
      # RubyLLM expects: { "call_id" => RubyLLM::ToolCall, ... }
      def parse_tool_calls(candle_tool_calls)
        return nil if candle_tool_calls.nil? || candle_tool_calls.empty?

        tool_calls = {}
        candle_tool_calls.each do |tc|
          call_id = "call_#{SecureRandom.hex(12)}"
          tool_calls[call_id] = RubyLLM::ToolCall.new(
            id: call_id,
            name: tc.name,
            arguments: tc.arguments
          )
        end
        tool_calls
      end

      # Format a tool call message (assistant message with tool_calls) for
      # sending back to the model. Injects tool calls into the content.
      def format_tool_call(msg)
        content = msg.content.to_s
        msg.tool_calls&.each_value do |tc|
          content += "\n<tool_call>\n#{JSON.generate({ name: tc.name, arguments: tc.arguments })}\n</tool_call>"
        end
        { role: "assistant", content: content }
      end

      # Format a tool result message for sending back to the model
      def format_tool_result(msg)
        { role: "tool", content: msg.content.to_s }
      end
    end
  end
end
