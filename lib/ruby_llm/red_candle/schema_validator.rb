# frozen_string_literal: true

module RubyLLM
  module RedCandle
    # Validates JSON schemas for structured generation
    module SchemaValidator
      class << self
        # Validate a schema for structured generation
        # @param schema [Hash] the JSON schema to validate
        # @raise [RubyLLM::Error] if the schema is invalid
        # @return [true] if validation passes
        def validate!(schema)
          errors = validate(schema)
          return true if errors.empty?

          raise RubyLLM::Error.new(
            nil,
            build_error_message(errors, schema)
          )
        end

        # Validate a schema and return any errors
        # @param schema [Hash] the JSON schema to validate
        # @return [Array<String>] list of validation errors (empty if valid)
        def validate(schema)
          errors = []

          # Check schema is a Hash
          unless schema.is_a?(Hash)
            errors << "Schema must be a Hash, got #{schema.class.name}"
            return errors # Can't continue validation
          end

          # Check type is "object"
          schema_type = schema[:type] || schema["type"]
          if schema_type.nil?
            errors << "Schema must have a 'type' field"
          elsif schema_type.to_s != "object"
            errors << "Schema type must be 'object' for structured generation, got '#{schema_type}'"
          end

          # Check properties exist and are valid
          properties = schema[:properties] || schema["properties"]
          if properties.nil?
            errors << "Schema must have a 'properties' field defining the expected output structure"
          elsif !properties.is_a?(Hash)
            errors << "Schema 'properties' must be a Hash, got #{properties.class.name}"
          elsif properties.empty?
            errors << "Schema 'properties' must define at least one property"
          else
            # Validate each property has a type
            properties.each do |key, value|
              unless value.is_a?(Hash)
                errors << "Property '#{key}' must be a Hash with at least a 'type' field"
                next
              end

              prop_type = value[:type] || value["type"]
              if prop_type.nil?
                errors << "Property '#{key}' must have a 'type' field"
              end
            end
          end

          errors
        end

        # Check if a schema is valid without raising
        # @param schema [Hash] the JSON schema to validate
        # @return [Boolean] true if valid
        def valid?(schema)
          validate(schema).empty?
        end

        private

        def build_error_message(errors, schema)
          message = ["Invalid schema for structured generation:"]
          errors.each { |e| message << "  - #{e}" }
          message << ""
          message << "Expected a JSON Schema like:"
          message << "  {"
          message << "    type: 'object',"
          message << "    properties: {"
          message << "      name: { type: 'string' },"
          message << "      age: { type: 'integer' }"
          message << "    },"
          message << "    required: ['name', 'age']"
          message << "  }"
          message << ""
          message << "Received: #{truncate_schema(schema)}"
          message.join("\n")
        end

        def truncate_schema(schema)
          str = schema.inspect
          str.length > 200 ? "#{str[0..200]}..." : str
        end
      end
    end
  end
end
