@spec = Gem::Specification.new do |s|
  s.name = "rye"
  s.rubyforge_project = "rye"
  s.version = "0.9.4"
  s.summary = "Rye: Safely run SSH commands on a bunch of machines at the same time (from Ruby)."
  s.description = s.summary
  s.author = "Delano Mandelbaum"
  s.email = "delano@solutious.com"
  s.homepage = "http://github.com/delano/rye/"
  
  # = DEPENDENCIES =
  # Add all gem dependencies
  s.add_dependency 'annoy'
  s.add_dependency 'sysinfo', '>= 0.7.3'
  
  s.add_dependency 'highline', '>= 1.5.1'
  s.add_dependency 'net-ssh', '>= 2.0.13'
  s.add_dependency 'net-scp', '>= 1.0.2'
  #s.add_dependency 'net-ssh-multi'
  
  # = EXECUTABLES =
  # The list of executables in your project (if any). Don't include the path, 
  # just the base filename.
  s.executables = %w[]
  
  # = MANIFEST =
  # The complete list of files to be included in the release. When GitHub packages your gem, 
  # it doesn't allow you to run any command that accesses the filesystem. You will get an
  # error. You can ask your VCS for the list of versioned files:
  # git ls-files
  # svn list -R
  s.files = %w(
  CHANGES.txt
  LICENSE.txt
  README.rdoc
  Rakefile
  Rudyfile
  bin/try
  lib/esc.rb
  lib/rye.rb
  lib/rye/box.rb
  lib/rye/cmd.rb
  lib/rye/key.rb
  lib/rye/rap.rb
  lib/rye/set.rb
  lib/rye/hop.rb
  rye.gemspec
  )
  
  s.extra_rdoc_files = %w[README.rdoc LICENSE.txt]
  s.has_rdoc = true
  s.rdoc_options = ["--line-numbers", "--title", s.summary, "--main", "README.rdoc"]
  s.require_paths = %w[lib]
  s.rubygems_version = '1.3.0'

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2
  end
  
end
