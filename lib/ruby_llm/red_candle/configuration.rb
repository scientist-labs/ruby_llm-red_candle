# frozen_string_literal: true

module RubyLLM
  module RedCandle
    # Configuration options for Red Candle provider
    module Configuration
      # Default JSON instruction template for structured generation
      # Use {schema_description} as a placeholder for the schema description
      DEFAULT_JSON_INSTRUCTION = "\n\nRespond with ONLY a valid JSON object containing: {schema_description}"

      class << self
        # Get the JSON instruction template
        # @return [String] the template with {schema_description} placeholder
        def json_instruction_template
          @json_instruction_template || DEFAULT_JSON_INSTRUCTION
        end

        # Set a custom JSON instruction template
        # @param template [String] the template with {schema_description} placeholder
        def json_instruction_template=(template)
          @json_instruction_template = template
        end

        # Reset configuration to defaults
        def reset!
          @json_instruction_template = nil
        end

        # Build the JSON instruction by substituting the schema description
        # @param schema_description [String] the human-readable schema description
        # @return [String] the formatted instruction
        def build_json_instruction(schema_description)
          json_instruction_template.gsub("{schema_description}", schema_description)
        end
      end
    end
  end
end
