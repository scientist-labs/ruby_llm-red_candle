# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyLLM::RedCandle::Configuration do
  after do
    # Reset configuration after each test
    described_class.reset!
  end

  describe ".json_instruction_template" do
    it "returns default template by default" do
      expect(described_class.json_instruction_template).to eq(
        described_class::DEFAULT_JSON_INSTRUCTION
      )
    end

    it "returns custom template when set" do
      custom = "Custom: {schema_description}"
      described_class.json_instruction_template = custom

      expect(described_class.json_instruction_template).to eq(custom)
    end
  end

  describe ".json_instruction_template=" do
    it "sets a custom template" do
      described_class.json_instruction_template = "Output JSON: {schema_description}"

      expect(described_class.json_instruction_template).to eq("Output JSON: {schema_description}")
    end

    it "setting nil causes fallback to default template" do
      described_class.json_instruction_template = "Custom"
      described_class.json_instruction_template = nil

      # After setting to nil, the getter returns the default (nil || DEFAULT)
      expect(described_class.json_instruction_template).to eq(described_class::DEFAULT_JSON_INSTRUCTION)
    end
  end

  describe ".reset!" do
    it "resets template to default" do
      described_class.json_instruction_template = "Custom template"
      described_class.reset!

      expect(described_class.json_instruction_template).to eq(
        described_class::DEFAULT_JSON_INSTRUCTION
      )
    end
  end

  describe ".build_json_instruction" do
    it "substitutes schema_description in default template" do
      result = described_class.build_json_instruction("name (string), age (integer)")

      expect(result).to include("name (string), age (integer)")
      expect(result).to include("Respond with ONLY a valid JSON object")
    end

    it "substitutes schema_description in custom template" do
      described_class.json_instruction_template = "Return JSON with: {schema_description}. Nothing else."

      result = described_class.build_json_instruction("field1, field2")

      expect(result).to eq("Return JSON with: field1, field2. Nothing else.")
    end

    it "handles template without placeholder" do
      described_class.json_instruction_template = "Always return valid JSON."

      result = described_class.build_json_instruction("ignored")

      expect(result).to eq("Always return valid JSON.")
    end

    it "handles multiple placeholders" do
      described_class.json_instruction_template = "{schema_description} - fields: {schema_description}"

      result = described_class.build_json_instruction("name, age")

      expect(result).to eq("name, age - fields: name, age")
    end
  end

  describe "DEFAULT_JSON_INSTRUCTION" do
    it "contains the schema_description placeholder" do
      expect(described_class::DEFAULT_JSON_INSTRUCTION).to include("{schema_description}")
    end

    it "instructs to respond with JSON" do
      expect(described_class::DEFAULT_JSON_INSTRUCTION).to match(/JSON/i)
    end
  end
end
