# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-12-04

### Added

- Initial release
- Red Candle provider for RubyLLM enabling local LLM execution
- Support for quantized GGUF models from HuggingFace
- Streaming token generation
- Structured output with JSON schemas
- Automatic model registration with RubyLLM
- Device selection (CPU, Metal, CUDA)
- Supported models:
  - google/gemma-3-4b-it-qat-q4_0-gguf
  - TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF
  - TheBloke/Mistral-7B-Instruct-v0.2-GGUF
  - Qwen/Qwen2.5-1.5B-Instruct-GGUF
  - microsoft/Phi-3-mini-4k-instruct
