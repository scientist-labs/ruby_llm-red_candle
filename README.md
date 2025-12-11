# RubyLLM::RedCandle

A [RubyLLM](https://github.com/crmne/ruby_llm) plugin that enables local LLM execution using quantized GGUF models through the [Red Candle](https://github.com/scientist-labs/red-candle) gem.

## What Makes This Different

While all other RubyLLM providers communicate via HTTP APIs, Red Candle runs models locally using the Candle Rust crate. This brings true local inference to Ruby with:

- **No network latency** - Models run directly on your machine
- **No API costs** - Free execution once models are downloaded
- **Privacy** - Your data never leaves your machine
- **Structured output** - Generate JSON conforming to schemas using grammar-constrained generation
- **Streaming** - Token-by-token output for responsive UIs
- **Hardware acceleration** - Metal (macOS), CUDA (NVIDIA), or CPU

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_llm-red_candle'
```

And then execute:

```bash
$ bundle install
```

**Note:** The `red-candle` gem requires a Rust toolchain to compile native extensions. See the [Red Candle installation guide](https://github.com/scientist-labs/red-candle#installation) for details.

## Quick Start

```ruby
require 'ruby_llm'
require 'ruby_llm-red_candle'

# Create a chat with a local model
chat = RubyLLM.chat(provider: :red_candle, model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF')

# Ask a question
response = chat.ask("What is the capital of France?")
puts response.content
```

## Usage

### Basic Chat (Non-Streaming)

The simplest way to use Red Candle is with synchronous chat:

```ruby
chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF'
)

response = chat.ask("What are the benefits of functional programming?")
puts response.content

# Access token estimates
puts "Input tokens: #{response.input_tokens}"
puts "Output tokens: #{response.output_tokens}"
```

### Multi-Turn Conversations

RubyLLM maintains conversation history automatically:

```ruby
chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF'
)

chat.ask("My name is Alice.")
chat.ask("I'm a software engineer who loves Ruby.")
response = chat.ask("What do you know about me?")
# The model remembers previous messages
puts response.content
```

### Streaming Output

For responsive UIs, stream tokens as they're generated:

```ruby
chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF'
)

chat.ask("Explain recursion step by step") do |chunk|
  print chunk.content  # Print each token as it arrives
  $stdout.flush
end
puts # Final newline
```

The block receives `RubyLLM::Chunk` objects with each generated token.

### Structured Output (JSON Schema)

Generate JSON output that conforms to a schema using grammar-constrained generation:

```ruby
chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF'
)

schema = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    age: { type: 'integer' },
    occupation: { type: 'string' }
  },
  required: ['name', 'age', 'occupation']
}

response = chat.with_schema(schema).ask("Generate a profile for a 30-year-old software engineer named Alice")

# response.content is automatically parsed as a Hash
puts response.content
# => {"name"=>"Alice", "age"=>30, "occupation"=>"Software Engineer"}

puts "Name: #{response.content['name']}"
puts "Age: #{response.content['age']}"
```

**How it works:** Red Candle uses the Rust `outlines-core` crate to constrain token generation to only produce valid JSON matching your schema. This ensures 100% valid output structure.

### Structured Output with Enums

Constrain values to specific options:

```ruby
schema = {
  type: 'object',
  properties: {
    sentiment: {
      type: 'string',
      enum: ['positive', 'negative', 'neutral']
    },
    confidence: { type: 'number' }
  },
  required: ['sentiment', 'confidence']
}

response = chat.with_schema(schema).ask("Analyze the sentiment: 'I love this product!'")
puts response.content['sentiment']  # => "positive"
```

### Using with ruby_llm-schema

For complex schemas, use [ruby_llm-schema](https://github.com/danielfriis/ruby_llm-schema):

```ruby
require 'ruby_llm/schema'

class PersonProfile
  include RubyLLM::Schema

  schema do
    string :name, description: "Person's full name"
    integer :age, description: "Age in years"
    string :occupation
    array :skills, items: { type: 'string' }
  end
end

chat = RubyLLM.chat(provider: :red_candle, model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF')
response = chat.with_schema(PersonProfile).ask("Generate a Ruby developer profile")
```

### Temperature Control

Adjust creativity vs determinism:

```ruby
# More creative/varied responses (higher temperature)
chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF'
)
chat.with_temperature(1.2).ask("Write a creative story opening")

# More focused/deterministic responses (lower temperature)
chat.with_temperature(0.3).ask("What is 15 + 27?")
```

Temperature range: 0.0 (deterministic) to 2.0 (very creative). Default is 0.7 for regular generation, 0.3 for structured output.

### System Prompts

Set context for the conversation:

```ruby
chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF'
)

chat.with_instructions("You are a helpful coding assistant specializing in Ruby. Always provide code examples.")

response = chat.ask("How do I read a file in Ruby?")
```

## Supported Models

| Model | Context Window | Size | Best For |
|-------|---------------|------|----------|
| `TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF` | 2,048 | ~600MB | Testing, quick prototypes |
| `Qwen/Qwen2.5-1.5B-Instruct-GGUF` | 32,768 | ~900MB | General chat, long context |
| `google/gemma-3-4b-it-qat-q4_0-gguf` | 8,192 | ~2.5GB | Balanced quality/speed |
| `microsoft/Phi-3-mini-4k-instruct` | 4,096 | ~2GB | Reasoning tasks |
| `TheBloke/Mistral-7B-Instruct-v0.2-GGUF` | 32,768 | ~4GB | High quality responses |

Models are automatically downloaded from HuggingFace on first use.

### Listing Available Models

```ruby
# Get all Red Candle models
models = RubyLLM.models.all.select { |m| m.provider == 'red_candle' }
models.each do |m|
  puts "#{m.id} - #{m.context_window} tokens"
end
```

## Configuration

### Device Selection

By default, Red Candle uses the best available device:
- **Metal** on macOS (Apple Silicon)
- **CUDA** if NVIDIA GPU is available
- **CPU** as fallback

Override with:

```ruby
RubyLLM.configure do |config|
  config.red_candle_device = 'cpu'    # Force CPU
  config.red_candle_device = 'metal'  # Force Metal (macOS)
  config.red_candle_device = 'cuda'   # Force CUDA (NVIDIA)
end
```

### HuggingFace Authentication

Some models require HuggingFace authentication (especially gated models like Mistral):

```bash
# Install the HuggingFace CLI
pip install huggingface_hub

# Login (creates ~/.huggingface/token)
huggingface-cli login
```

See the [Red Candle HuggingFace guide](https://github.com/scientist-labs/red-candle/blob/main/docs/HUGGINGFACE.md) for details.

### Custom JSON Instruction Template

By default, structured generation appends instructions to guide the model to output JSON. You can customize this template for different models or use cases:

```ruby
# View the default template
RubyLLM::RedCandle::Configuration.json_instruction_template
# => "\n\nRespond with ONLY a valid JSON object containing: {schema_description}"

# Set a custom template (use {schema_description} as placeholder)
RubyLLM::RedCandle::Configuration.json_instruction_template = <<~TEMPLATE

  You must respond with valid JSON matching this structure: {schema_description}
  Do not include any other text, only the JSON object.
TEMPLATE

# Reset to default
RubyLLM::RedCandle::Configuration.reset!
```

Different models may respond better to different phrasings. Experiment with templates if you're getting inconsistent structured output.

### Debug Logging

Enable debug logging to troubleshoot issues:

```ruby
RubyLLM.logger.level = Logger::DEBUG
```

This shows:
- Schema normalization details
- Prompt construction
- Generation parameters
- Raw model outputs

## Error Handling

```ruby
begin
  chat = RubyLLM.chat(provider: :red_candle, model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF')
  response = chat.ask("Hello!")
rescue RubyLLM::Error => e
  puts "Error: #{e.message}"
end
```

Common errors:
- **Model not found** - Check model ID spelling
- **Failed to load tokenizer** - Model may require HuggingFace login
- **Context length exceeded** - Reduce conversation length or use model with larger context window
- **Invalid schema** - Schema must be `type: 'object'` with `properties` defined
- **Structured generation failed** - Schema may be too complex; try simplifying

### Schema Validation

Schemas are validated before generation. Invalid schemas produce helpful error messages:

```ruby
# This will fail with a descriptive error
invalid_schema = { type: "array" }  # Must be 'object' with properties
chat.with_schema(invalid_schema).ask("...")
# => RubyLLM::Error: Invalid schema for structured generation:
#      - Schema type must be 'object' for structured generation, got 'array'
#      - Schema must have a 'properties' field...
```

Valid schemas must have:
- `type: 'object'`
- `properties` hash with at least one property
- Each property must have a `type` field

## Limitations

- **No tool/function calling** - Red Candle models don't support tool use
- **No vision** - Text-only input supported
- **No embeddings** - Chat models only (embedding support planned)
- **No audio** - Text-only modality

## Performance Tips

1. **Choose the right model size** - TinyLlama (1.1B) is fast but less capable; Mistral (7B) is slower but higher quality
2. **Use streaming for long responses** - Better UX than waiting for full generation
3. **Lower temperature for structured output** - More deterministic JSON generation
4. **Reuse chat instances** - Model loading is expensive; reuse loaded models

## Development

After checking out the repo, run `bin/setup` to install dependencies.

### Running Tests

```bash
# Fast tests with mocked responses (default)
bundle exec rspec

# Real inference tests (slow, downloads models)
RED_CANDLE_REAL_INFERENCE=true bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/scientist-labs/ruby_llm-red_candle.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Related Projects

- [RubyLLM](https://github.com/crmne/ruby_llm) - The unified Ruby LLM interface
- [Red Candle](https://github.com/scientist-labs/red-candle) - Ruby bindings for the Candle ML framework
- [ruby_llm-mcp](https://github.com/patvice/ruby_llm-mcp) - MCP protocol support for RubyLLM
- [ruby_llm-schema](https://github.com/danielfriis/ruby_llm-schema) - JSON Schema DSL for RubyLLM
