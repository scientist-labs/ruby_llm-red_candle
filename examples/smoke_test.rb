#!/usr/bin/env ruby
# frozen_string_literal: true

# Smoke test for RubyLLM::RedCandle
# Run with: bundle exec ruby examples/smoke_test.rb
#
# This script demonstrates all the features documented in the README.
# It uses TinyLlama by default as it's the fastest model to download and run.

require "bundler/setup"
require "ruby_llm"
require "ruby_llm-red_candle"

# Configuration
MODEL = ENV.fetch("SMOKE_TEST_MODEL", "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF")
SKIP_SLOW = ENV.fetch("SKIP_SLOW", nil) # Set to skip multi-turn and streaming tests

# Helper for printing section headers
def section(title)
  puts
  puts "=" * 60
  puts " #{title}"
  puts "=" * 60
  puts
end

# Helper for printing test results
def result(label, value)
  puts "  #{label}: #{value}"
end

def success(message)
  puts "  [OK] #{message}"
end

def info(message)
  puts "  [INFO] #{message}"
end

begin
  section "RubyLLM::RedCandle Smoke Test"
  info "Model: #{MODEL}"
  info "Ruby: #{RUBY_VERSION}"
  info "RubyLLM: #{RubyLLM::VERSION}"
  info "RedCandle: #{RubyLLM::RedCandle::VERSION}"

  # ---------------------------------------------------------------------------
  section "1. Listing Available Models"
  # ---------------------------------------------------------------------------

  models = RubyLLM.models.all.select { |m| m.provider == "red_candle" }
  puts "  Available Red Candle models:"
  models.each do |m|
    puts "    - #{m.id} (#{m.context_window} tokens)"
  end
  success "Found #{models.size} models"

  # ---------------------------------------------------------------------------
  section "2. Basic Chat (Non-Streaming)"
  # ---------------------------------------------------------------------------

  info "Creating chat instance..."
  chat = RubyLLM.chat(provider: :red_candle, model: MODEL)
  success "Chat created"

  info "Asking: 'What is 2 + 2?'"
  response = chat.ask("What is 2 + 2? Answer with just the number.")

  result "Response", response.content.strip
  result "Input tokens (estimated)", response.input_tokens
  result "Output tokens (estimated)", response.output_tokens
  success "Basic chat completed"

  # ---------------------------------------------------------------------------
  section "3. Multi-Turn Conversation"
  # ---------------------------------------------------------------------------

  unless SKIP_SLOW
    info "Creating new chat for multi-turn..."
    chat = RubyLLM.chat(provider: :red_candle, model: MODEL)

    info "Turn 1: 'My name is Alice.'"
    chat.ask("My name is Alice.")

    info "Turn 2: 'I love programming in Ruby.'"
    chat.ask("I love programming in Ruby.")

    info "Turn 3: 'What is my name and what do I love?'"
    response = chat.ask("What is my name and what do I love? Be brief.")

    result "Response", response.content.strip[0..200]
    success "Multi-turn conversation completed"
  else
    info "Skipped (SKIP_SLOW is set)"
  end

  # ---------------------------------------------------------------------------
  section "4. Streaming Output"
  # ---------------------------------------------------------------------------

  unless SKIP_SLOW
    info "Creating chat for streaming..."
    chat = RubyLLM.chat(provider: :red_candle, model: MODEL)

    info "Streaming response for: 'Count from 1 to 5'"
    print "  Response: "

    chunks = []
    chat.ask("Count from 1 to 5, just list the numbers.") do |chunk|
      print chunk.content
      $stdout.flush
      chunks << chunk
    end
    puts

    result "Chunks received", chunks.size
    success "Streaming completed"
  else
    info "Skipped (SKIP_SLOW is set)"
  end

  # ---------------------------------------------------------------------------
  section "5. Temperature Control"
  # ---------------------------------------------------------------------------

  info "Testing low temperature (0.1) - more deterministic..."
  chat = RubyLLM.chat(provider: :red_candle, model: MODEL)
  response = chat.with_temperature(0.1).ask("What is the capital of France? One word answer.")
  result "Low temp response", response.content.strip

  info "Testing high temperature (1.5) - more creative..."
  response = chat.with_temperature(1.5).ask("Say something creative about the moon in 10 words or less.")
  result "High temp response", response.content.strip

  success "Temperature control completed"

  # ---------------------------------------------------------------------------
  section "6. System Prompts (Instructions)"
  # ---------------------------------------------------------------------------

  info "Setting system prompt for a pirate assistant..."
  chat = RubyLLM.chat(provider: :red_candle, model: MODEL)
  chat.with_instructions("You are a pirate. Always respond like a pirate would, using pirate slang.")

  response = chat.ask("Hello, how are you today?")
  result "Pirate response", response.content.strip[0..150]
  success "System prompts completed"

  # ---------------------------------------------------------------------------
  section "7. Structured Output (JSON Schema)"
  # ---------------------------------------------------------------------------

  info "Defining schema for person profile..."
  schema = {
    type: "object",
    properties: {
      name: { type: "string" },
      age: { type: "integer" },
      occupation: { type: "string" }
    },
    required: %w[name age occupation]
  }

  info "Generating structured output..."
  chat = RubyLLM.chat(provider: :red_candle, model: MODEL)
  response = chat.with_schema(schema).ask("Generate a profile for a 28-year-old teacher named Bob")

  result "Response type", response.content.class
  result "Response", response.content.inspect

  if response.content.is_a?(Hash)
    result "Name", response.content["name"]
    result "Age", response.content["age"]
    result "Occupation", response.content["occupation"]
    success "Structured output returned a Hash"
  else
    info "Response was a String (may indicate parse issue): #{response.content}"
  end

  # ---------------------------------------------------------------------------
  section "8. Structured Output with Enums"
  # ---------------------------------------------------------------------------

  info "Defining schema with enum constraint..."
  sentiment_schema = {
    type: "object",
    properties: {
      sentiment: {
        type: "string",
        enum: %w[positive negative neutral]
      },
      confidence: { type: "number" }
    },
    required: %w[sentiment confidence]
  }

  info "Analyzing sentiment..."
  chat = RubyLLM.chat(provider: :red_candle, model: MODEL)
  response = chat.with_schema(sentiment_schema).ask("Analyze: 'I absolutely love this product!'")

  result "Response", response.content.inspect

  if response.content.is_a?(Hash)
    result "Sentiment", response.content["sentiment"]
    result "Confidence", response.content["confidence"]
    success "Enum-constrained output completed"
  end

  # ---------------------------------------------------------------------------
  section "9. Structured Output with String Keys (Normalization)"
  # ---------------------------------------------------------------------------

  info "Testing schema with string keys (should be normalized to symbols)..."
  string_key_schema = {
    "type" => "object",
    "properties" => {
      "answer" => { "type" => "string" }
    },
    "required" => ["answer"]
  }

  chat = RubyLLM.chat(provider: :red_candle, model: MODEL)
  response = chat.with_schema(string_key_schema).ask("What is 3 + 3?")

  result "Response", response.content.inspect
  success "String key normalization completed"

  # ---------------------------------------------------------------------------
  section "10. Error Handling"
  # ---------------------------------------------------------------------------

  info "Testing error handling with invalid model..."
  begin
    RubyLLM.chat(provider: :red_candle, model: "invalid/nonexistent-model")
    puts "  [FAIL] Should have raised an error"
  rescue RubyLLM::Error => e
    result "Error caught", e.message[0..60]
    success "Error handling works correctly"
  end

  # ---------------------------------------------------------------------------
  section "Summary"
  # ---------------------------------------------------------------------------

  puts "  All smoke tests completed successfully!"
  puts
  puts "  To run with a different model:"
  puts "    SMOKE_TEST_MODEL='Qwen/Qwen2.5-1.5B-Instruct-GGUF' bundle exec ruby examples/smoke_test.rb"
  puts
  puts "  To skip slow tests:"
  puts "    SKIP_SLOW=1 bundle exec ruby examples/smoke_test.rb"
  puts

rescue StandardError => e
  puts
  puts "  [ERROR] #{e.class}: #{e.message}"
  puts e.backtrace.first(5).map { |line| "    #{line}" }.join("\n")
  exit 1
end
