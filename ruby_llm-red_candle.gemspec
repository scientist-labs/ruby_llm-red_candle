# frozen_string_literal: true

require_relative "lib/ruby_llm/red_candle/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm-red_candle"
  spec.version = RubyLLM::RedCandle::VERSION
  spec.authors = ["Chris Petersen"]
  spec.email = ["chris@scientist.com"]

  spec.summary = "Red Candle provider for RubyLLM - local LLM execution using quantized GGUF models"
  spec.description = <<~DESC
    A RubyLLM plugin that enables local LLM execution using the Red Candle gem.
    Run quantized GGUF models directly in Ruby without external API calls.
    Supports streaming, structured output, and multiple model architectures
    including Gemma, Llama, Qwen, Mistral, and Phi.
  DESC
  spec.homepage = "https://github.com/scientist-labs/ruby_llm-red_candle"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "ruby_llm", ">= 1.2", "< 3.0"
  spec.add_dependency "red-candle", "~> 1.3"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
end
