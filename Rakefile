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
