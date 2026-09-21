require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'fileutils'

RSpec::Core::RakeTask.new(:spec)

require "rake/extensiontask"

task :build => :compile

GEMSPEC = Gem::Specification.load("zstd-ruby.gemspec")

# Platforms we ship precompiled gems for. Each one has a matching
# rake-compiler-dock image (ghcr.io/rake-compiler/rake-compiler-dock-image).
CROSS_PLATFORMS = %w[
  x86_64-linux
  aarch64-linux
  x86_64-linux-musl
  aarch64-linux-musl
  x86_64-darwin
  arm64-darwin
]

# Ruby ABIs baked into each precompiled gem. rake-compiler derives the gem's
# required_ruby_version from this list, so anything outside it (2.7, 3.0, and
# future Rubies) falls back to building from the source gem. Each ABI adds
# roughly 800KB of binary to every platform gem, so keep the list tight.
CROSS_RUBY_VERSIONS = %w[3.1 3.2 3.3 3.4 4.0]

Rake::ExtensionTask.new("zstdruby", GEMSPEC) do |ext|
  ext.lib_dir = "lib/zstd-ruby"
  ext.ext_dir = "ext/zstdruby"
  ext.cross_compile = true
  ext.cross_platform = CROSS_PLATFORMS
  ext.cross_compiling do |spec|
    # The binaries are already in the gem and the extension is cleared, so
    # libzstd's sources (2.2MB) are dead weight here.
    spec.files.reject! { |path| path.start_with?("ext/") }
  end
end

task :default => [:clobber, :compile, :spec]

namespace :gem do
  CROSS_PLATFORMS.each do |platform|
    desc "Build the precompiled gem for #{platform} (requires docker)"
    task platform do
      require "rake_compiler_dock"

      ruby_cc_version = RakeCompilerDock.ruby_cc_version(*CROSS_RUBY_VERSIONS)
      # BUNDLE_APP_CONFIG keeps the container off the host's .bundle/config,
      # which points at a vendor path built for a different Ruby.
      RakeCompilerDock.sh(<<~CMD, platform: platform, verbose: true)
        export BUNDLE_APP_CONFIG=/tmp/bundle &&
        bundle install &&
        RUBY_CC_VERSION=#{ruby_cc_version} bundle exec rake native:#{platform} gem
      CMD
    end
  end

  desc "Build the precompiled gems for every platform (requires docker)"
  task :native => CROSS_PLATFORMS.map { |platform| "gem:#{platform}" }
end

desc 'Sync zstd libs dirs to ext/zstdruby/libzstd'
task :zstd_update do
  FileUtils.rm_r("ext/zstdruby/libzstd")
  FileUtils.mkdir_p("ext/zstdruby/libzstd")
  ["common", "compress", "decompress", "dictBuilder"].each do |dir|
    FileUtils.cp_r("zstd/lib/#{dir}", "ext/zstdruby/libzstd/#{dir}")
  end
  FileUtils.cp_r('zstd/lib/zdict.h', 'ext/zstdruby/libzstd')
  FileUtils.cp_r('zstd/lib/zstd.h', 'ext/zstdruby/libzstd')
  FileUtils.cp_r('zstd/lib/zstd_errors.h', 'ext/zstdruby/libzstd')
end
