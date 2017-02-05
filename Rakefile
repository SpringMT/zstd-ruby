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
  FileUtils.rm_r('ext/zstdruby/libzstd')
  FileUtils.cp_r('zstd/lib', 'ext/zstdruby/libzstd')
end
