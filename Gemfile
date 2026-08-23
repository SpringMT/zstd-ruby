source 'https://rubygems.org'

# Specify your gem's dependencies in zstd_ruby.gemspec
gemspec

if RUBY_PLATFORM.include?('linux') && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.0.0')
  gem 'ruby_memcheck', '~> 3.0'
end
