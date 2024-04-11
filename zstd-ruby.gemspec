# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'zstd-ruby/version'

Gem::Specification.new do |spec|
  spec.name          = "zstd-ruby"
  spec.version       = Zstd::VERSION
  spec.authors       = ["SpringMT"]
  spec.email         = ["today.is.sky.blue.sky@gmail.com"]

  spec.summary       = %q{Ruby binding for zstd(Zstandard - Fast real-time compression algorithm)}
  spec.description   = %q{Ruby binding for zstd(Zstandard - Fast real-time compression algorithm). See https://github.com/facebook/zstd}
  spec.homepage      = "https://github.com/SpringMT/zstd-ruby"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  #if spec.respond_to?(:metadata)
  #  spec.metadata['allowed_push_host'] = "Set to 'http://mygemserver.com'"
  #else
  #  raise "RubyGems 2.0 or newer is required to protect against " \
  #    "public gem pushes."
  #end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|benchmarks|zstd|.github|examples)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions    = ["ext/zstdruby/extconf.rb"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler", '~> 1'
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
end
