# RubyLLM::RedCandle v0.1.0

**The first RubyLLM provider that runs models locally.**

## What is it?

RubyLLM::RedCandle is a plugin for [RubyLLM](https://github.com/crmne/ruby_llm) that enables local LLM execution using quantized GGUF models. While other RubyLLM providers connect to cloud APIs (OpenAI, Anthropic, etc.), Red Candle runs models directly in your Ruby process using the [Candle](https://github.com/huggingface/candle) ML framework via Rust bindings.

## Why it matters

- **No API costs** - Run inference for free once models are downloaded
- **No network latency** - Models execute locally, no round-trips to external servers
- **Data privacy** - Your prompts and responses never leave your machine
- **Offline capable** - Works without internet after initial model download
- **Hardware acceleration** - Metal (Apple Silicon), CUDA (NVIDIA), or CPU

## Features

### Full RubyLLM compatibility
Drop-in replacement for cloud providers - same `RubyLLM.chat` interface you already know:

```ruby
chat = RubyLLM.chat(provider: :red_candle, model: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF')
response = chat.ask("What is the capital of France?")
```

### Streaming output
Token-by-token generation for responsive UIs:

```ruby
chat.ask("Explain recursion") { |chunk| print chunk.content }
```

### Structured output (JSON Schema)
Grammar-constrained generation ensures valid JSON every time:

```ruby
schema = {
  type: 'object',
  properties: {
    name: { type: 'string' },
    age: { type: 'integer' }
  },
  required: ['name', 'age']
}

response = chat.with_schema(schema).ask("Generate a person profile")
response.content  # => {"name"=>"Alice", "age"=>30}
```

### Schema validation
Invalid schemas fail fast with helpful error messages showing what's wrong and how to fix it.

### Configurable JSON instruction templates
Tune the prompt template used for structured generation to optimize for different models.

### Helpful error messages
Raw Rust/Candle errors are wrapped with context-specific guidance (OOM, context length, model loading issues).

## Supported Models

| Model | Context | Size | Use Case |
|-------|---------|------|----------|
| TinyLlama-1.1B | 2K | ~600MB | Testing, prototypes |
| Qwen2.5-1.5B-Instruct | 32K | ~900MB | General chat, long context |
| Gemma-3-4B | 8K | ~2.5GB | Balanced quality/speed |
| Phi-3-mini-4k | 4K | ~2GB | Reasoning tasks |
| Mistral-7B-Instruct | 32K | ~4GB | High quality responses |

Models are automatically downloaded from HuggingFace on first use.

## Requirements

- Ruby 3.1+
- Rust toolchain (for native extension compilation)
- RubyLLM >= 1.2

## Installation

```ruby
gem 'ruby_llm-red_candle'
```

## Links

- [Documentation](https://github.com/scientist-labs/ruby_llm-red_candle#readme)
- [RubyLLM](https://github.com/crmne/ruby_llm)
- [Red Candle](https://github.com/scientist-labs/red-candle)
