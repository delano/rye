require "rubygems"
require "rake"
require "rake/clean"
require 'yaml'

require 'rdoc/task'

config = YAML.load_file("BUILD.yml")
task :default => ["build"]
CLEAN.include [ 'pkg', 'rdoc' ]
name = "rye"

begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|
    gem.version = "#{config[:MAJOR]}.#{config[:MINOR]}.#{config[:PATCH]}"
    gem.name = name
    gem.rubyforge_project = gem.name
    gem.summary = "Run SSH commands on a bunch of machines at the same time (from Ruby)."
    gem.description = "Run SSH commands on a bunch of machines at the same time (from Ruby)."
    gem.email = "delano@solutious.com"
    gem.homepage = "https://github.com/delano/rye"
    gem.authors = ["Delano Mandelbaum"]
    gem.add_dependency 'annoy'
    gem.add_dependency 'sysinfo',         '>= 0.7.3'
    gem.add_dependency 'highline',        '>= 1.5.1'
    gem.add_dependency 'net-ssh',         '>= 2.0.13'
    gem.add_dependency 'net-scp',         '>= 1.0.2'
    gem.add_dependency 'docile',          '>= 1.0.1'
    #gem.add_dependency 'net-ssh-multi'
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

RDoc::Task.new do |rdoc|
  version = "#{config[:MAJOR]}.#{config[:MINOR]}.#{config[:PATCH]}"
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "#{name} #{version}"
  rdoc.rdoc_files.include("README*")
  rdoc.rdoc_files.include("LICENSE.txt")
  rdoc.rdoc_files.include("bin/*.rb")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

