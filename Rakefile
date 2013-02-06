require "rubygems"
require "rake"
require "rake/clean"
require "rdoc/task"

task :default => ["build"]
CLEAN.include [ 'pkg', 'rdoc' ]
name = "rye"

$:.unshift File.join(File.dirname(__FILE__), 'lib')
puts $:
require name

version = Rye::VERSION.to_s

begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|
    gem.version = version
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
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "#{name} #{version}"
  rdoc.rdoc_files.include("README*")
  rdoc.rdoc_files.include("LICENSE.txt")
  rdoc.rdoc_files.include("VERSION")
  rdoc.rdoc_files.include("bin/*.rb")
  rdoc.rdoc_files.include("lib/**/*.rb")
end

