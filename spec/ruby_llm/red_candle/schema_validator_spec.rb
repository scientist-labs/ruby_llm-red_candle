# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::RedCandle::SchemaValidator do
  describe ".validate" do
    context "with a valid schema" do
      it "returns empty array for minimal valid schema" do
        schema = {
          type: "object",
          properties: {
            name: { type: "string" }
          }
        }

        expect(described_class.validate(schema)).to be_empty
      end

      it "returns empty array for schema with multiple properties" do
        schema = {
          type: "object",
          properties: {
            name: { type: "string" },
            age: { type: "integer" },
            active: { type: "boolean" }
          },
          required: %w[name age]
        }

        expect(described_class.validate(schema)).to be_empty
      end

      it "returns empty array for schema with string keys" do
        schema = {
          "type" => "object",
          "properties" => {
            "name" => { "type" => "string" }
          }
        }

        expect(described_class.validate(schema)).to be_empty
      end
    end

    context "with invalid schema" do
      it "returns error when schema is nil" do
        errors = described_class.validate(nil)

        expect(errors).to include(/must be a Hash/)
      end

      it "returns error when schema is a string" do
        errors = described_class.validate("not a schema")

        expect(errors).to include(/must be a Hash, got String/)
      end

      it "returns error when schema is an array" do
        errors = described_class.validate([])

        expect(errors).to include(/must be a Hash, got Array/)
      end

      it "returns error when type is missing" do
        schema = { properties: { name: { type: "string" } } }
        errors = described_class.validate(schema)

        expect(errors).to include(/must have a 'type' field/)
      end

      it "returns error when type is not 'object'" do
        schema = { type: "array", properties: { name: { type: "string" } } }
        errors = described_class.validate(schema)

        expect(errors).to include(/type must be 'object'.*got 'array'/)
      end

      it "returns error when properties is missing" do
        schema = { type: "object" }
        errors = described_class.validate(schema)

        expect(errors).to include(/must have a 'properties' field/)
      end

      it "returns error when properties is not a Hash" do
        schema = { type: "object", properties: "invalid" }
        errors = described_class.validate(schema)

        expect(errors).to include(/'properties' must be a Hash/)
      end

      it "returns error when properties is empty" do
        schema = { type: "object", properties: {} }
        errors = described_class.validate(schema)

        expect(errors).to include(/must define at least one property/)
      end

      it "returns error when property is not a Hash" do
        schema = { type: "object", properties: { name: "string" } }
        errors = described_class.validate(schema)

        expect(errors).to include(/Property 'name' must be a Hash/)
      end

      it "returns error when property has no type" do
        schema = { type: "object", properties: { name: { description: "A name" } } }
        errors = described_class.validate(schema)

        expect(errors).to include(/Property 'name' must have a 'type' field/)
      end

      it "collects multiple errors" do
        schema = { properties: { name: "invalid" } }
        errors = described_class.validate(schema)

        expect(errors.size).to be >= 2
        expect(errors).to include(/must have a 'type' field/)
        expect(errors).to include(/Property 'name' must be a Hash/)
      end

      it "validates multiple properties independently" do
        schema = {
          type: "object",
          properties: {
            valid_prop: { type: "string" },
            invalid_prop: { description: "missing type" }
          }
        }
        errors = described_class.validate(schema)

        # Only the invalid property should produce an error
        expect(errors.size).to eq(1)
        expect(errors.first).to include("invalid_prop")
        expect(errors.first).to include("must have a 'type' field")
      end
    end
  end

  describe ".validate!" do
    it "returns true for valid schema" do
      schema = {
        type: "object",
        properties: { name: { type: "string" } }
      }

      expect(described_class.validate!(schema)).to be true
    end

    it "raises RubyLLM::Error for invalid schema" do
      schema = { type: "object" }

      expect { described_class.validate!(schema) }.to raise_error(RubyLLM::Error)
    end

    it "includes all errors in the error message" do
      schema = { type: "array" }

      expect { described_class.validate!(schema) }.to raise_error(RubyLLM::Error) do |error|
        expect(error.message).to include("type must be 'object'")
        expect(error.message).to include("must have a 'properties' field")
      end
    end

    it "includes example schema in error message" do
      schema = nil

      expect { described_class.validate!(schema) }.to raise_error(RubyLLM::Error) do |error|
        expect(error.message).to include("Expected a JSON Schema like:")
        expect(error.message).to include("type: 'object'")
        expect(error.message).to include("properties:")
      end
    end

    it "includes received schema in error message" do
      schema = { invalid: true }

      expect { described_class.validate!(schema) }.to raise_error(RubyLLM::Error) do |error|
        expect(error.message).to include("Received:")
        expect(error.message).to include(":invalid=>true")
      end
    end
  end

  describe ".valid?" do
    it "returns true for valid schema" do
      schema = {
        type: "object",
        properties: { name: { type: "string" } }
      }

      expect(described_class.valid?(schema)).to be true
    end

    it "returns false for invalid schema" do
      expect(described_class.valid?(nil)).to be false
      expect(described_class.valid?({})).to be false
      expect(described_class.valid?({ type: "object" })).to be false
    end
  end
end
