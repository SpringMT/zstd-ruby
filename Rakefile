require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rake/extensiontask"

task :build => :compile

Rake::ExtensionTask.new("zstd_ruby") do |ext|
  ext.lib_dir = "lib/zstd_ruby"
end

task :default => [:clobber, :compile, :spec]
