# RubyLLM::RedCandle

A [RubyLLM](https://github.com/crmne/ruby_llm) plugin that enables local LLM execution using quantized GGUF models through the [Red Candle](https://github.com/scientist-labs/red-candle) gem.

## What Makes This Different

While all other RubyLLM providers communicate via HTTP APIs, Red Candle runs models locally using the Candle Rust crate. This brings true local inference to Ruby with:

- **No network latency** - Models run directly on your machine
- **No API costs** - Free execution once models are downloaded
- **Privacy** - Your data never leaves your machine
- **Structured output** - Generate JSON conforming to schemas
- **Streaming** - Token-by-token output for responsive UIs

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

## Usage

### Basic Chat

```ruby
require 'ruby_llm'
require 'ruby_llm-red_candle'

chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF'
)

response = chat.ask("What are the benefits of functional programming?")
puts response.content
```

### Streaming

```ruby
chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF'
)

chat.ask("Explain recursion") do |chunk|
  print chunk.content
end
```

### Structured Output

```ruby
chat = RubyLLM.chat(
  provider: :red_candle,
  model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF'
)

schema = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    age: { type: 'integer' }
  },
  required: ['name', 'age']
}

response = chat.with_schema(schema).ask("Generate a person profile for someone named Alice who is 30 years old")
data = response.content  # Returns a Hash when structured generation succeeds
puts "Name: #{data['name']}, Age: #{data['age']}"
```

**Note:** Structured output works best with smaller, well-defined schemas. TinyLlama is recommended for testing structured generation.

## Supported Models

| Model | Context Window | Description |
|-------|---------------|-------------|
| `google/gemma-3-4b-it-qat-q4_0-gguf` | 8,192 | Gemma 3 4B Instruct (Quantized) |
| `TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF` | 2,048 | TinyLlama 1.1B Chat - Great for testing |
| `TheBloke/Mistral-7B-Instruct-v0.2-GGUF` | 32,768 | Mistral 7B Instruct v0.2 |
| `Qwen/Qwen2.5-1.5B-Instruct-GGUF` | 32,768 | Qwen 2.5 1.5B Instruct |
| `microsoft/Phi-3-mini-4k-instruct` | 4,096 | Phi 3 Mini 4K Instruct |

Models are automatically downloaded from HuggingFace on first use.

## Configuration

### Device Selection

By default, Red Candle uses the best available device (Metal on Mac, CUDA if available, otherwise CPU). You can override this:

```ruby
RubyLLM.configure do |config|
  config.red_candle_device = 'cpu'    # Force CPU
  config.red_candle_device = 'metal'  # Force Metal (macOS)
  config.red_candle_device = 'cuda'   # Force CUDA (NVIDIA)
end
```

### HuggingFace Authentication

Some models require HuggingFace authentication (especially gated models like Mistral). Login first:

```bash
huggingface-cli login
```

See the [Red Candle HuggingFace guide](https://github.com/scientist-labs/red-candle/blob/main/docs/HUGGINGFACE.md) for details.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

### Testing Modes

Tests run with mocked responses by default for speed:

```bash
# Fast tests with mocked responses (default)
bundle exec rspec

# Real inference tests (slow, downloads models)
RED_CANDLE_REAL_INFERENCE=true bundle exec rspec
```

## Limitations

- **No tool/function calling** - Red Candle models don't support tool use
- **No vision** - Text-only input supported
- **No embeddings** - Chat models only (embedding support planned)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/scientist-labs/ruby_llm-red_candle.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Related Projects

- [RubyLLM](https://github.com/crmne/ruby_llm) - The unified Ruby LLM interface
- [Red Candle](https://github.com/scientist-labs/red-candle) - Ruby bindings for the Candle ML framework
- [ruby_llm-mcp](https://github.com/patvice/ruby_llm-mcp) - MCP protocol support for RubyLLM
- [ruby_llm-schema](https://github.com/danielfriis/ruby_llm-schema) - JSON Schema DSL for RubyLLM
