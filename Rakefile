require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'fileutils'

RSpec::Core::RakeTask.new(:spec)

require "rake/extensiontask"

task :build => :compile

Rake::ExtensionTask.new("zstdruby") do |ext|
  ext.lib_dir = "lib/zstd-ruby"
  ext.ext_dir = "ext/zstdruby"
end

task :default => [:clobber, :compile, :spec]

begin
  require 'ruby_memcheck'
  require 'ruby_memcheck/rspec/rake_task'

  RubyMemcheck.config(
    binary_name: 'zstdruby',
    # Valgrind and YJIT interfere with each other, adding noise and slowdown,
    # so keep YJIT disabled while running under Valgrind.
    ruby: "#{FileUtils::RUBY} --disable-yjit"
  )

  namespace :spec do
    task :check_valgrind do
      unless system('command -v valgrind > /dev/null 2>&1')
        abort("\nValgrind is required for `rake spec:valgrind` but was not found.\n" \
              "Install it first (Linux only), e.g. `sudo apt-get install valgrind`.\n")
      end
    end

    RubyMemcheck::RSpec::RakeTask.new(valgrind: [:check_valgrind, :compile])
  end
rescue LoadError
  # ruby_memcheck is an optional development dependency, absent on the platforms
  # and Ruby versions the Gemfile excludes. Skip the task instead of breaking.
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
