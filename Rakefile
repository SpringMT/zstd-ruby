require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rake/extensiontask"

task :build => :compile

Rake::ExtensionTask.new("zstdruby") do |ext|
  ext.lib_dir = "lib/zstd-ruby"
  ext.ext_dir = "ext/zstdruby"
end

task :default => [:clobber, :compile, :spec]

#task :sync

