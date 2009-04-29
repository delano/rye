@spec = Gem::Specification.new do |s|
  s.name = "rye"
  s.rubyforge_project = "rye"
  s.version = "0.6.2"
  s.summary = "Rye: Safely run SSH commands on a bunch of machines at the same time (from Ruby)."
  s.description = s.summary
  s.author = "Delano Mandelbaum"
  s.email = "delano@solutious.com"
  s.homepage = "http://solutious.com/"
  
  # = DEPENDENCIES =
  # Add all gem dependencies
  s.add_dependency 'net-ssh'
  s.add_dependency 'net-scp'
  s.add_dependency 'highline'
  s.add_dependency 'drydock'
  
  # = EXECUTABLES =
  # The list of executables in your project (if any). Don't include the path, 
  # just the base filename.
  s.executables = %w[rye]
  
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
  bin/rye
  bin/try
  lib/esc.rb
  lib/rye.rb
  lib/rye/box.rb
  lib/rye/cmd.rb
  lib/rye/key.rb
  lib/rye/rap.rb
  lib/rye/set.rb
  lib/sys.rb
  rye.gemspec
  try/copying.rb
  try/keys.rb
  tst/10-key1
  tst/10-key1.pub
  tst/10-key2
  tst/10-key2.pub
  tst/10_keys_test.rb
  tst/50_rset_test.rb
  tst/60-file.mp3
  tst/60_rbox_transfer_test.rb
  tst/70_rbox_env_test.rb
  vendor/highline-1.5.1/CHANGELOG
  vendor/highline-1.5.1/INSTALL
  vendor/highline-1.5.1/LICENSE
  vendor/highline-1.5.1/README
  vendor/highline-1.5.1/Rakefile
  vendor/highline-1.5.1/TODO
  vendor/highline-1.5.1/examples/ansi_colors.rb
  vendor/highline-1.5.1/examples/asking_for_arrays.rb
  vendor/highline-1.5.1/examples/basic_usage.rb
  vendor/highline-1.5.1/examples/color_scheme.rb
  vendor/highline-1.5.1/examples/limit.rb
  vendor/highline-1.5.1/examples/menus.rb
  vendor/highline-1.5.1/examples/overwrite.rb
  vendor/highline-1.5.1/examples/page_and_wrap.rb
  vendor/highline-1.5.1/examples/password.rb
  vendor/highline-1.5.1/examples/trapping_eof.rb
  vendor/highline-1.5.1/examples/using_readline.rb
  vendor/highline-1.5.1/lib/highline.rb
  vendor/highline-1.5.1/lib/highline/color_scheme.rb
  vendor/highline-1.5.1/lib/highline/compatibility.rb
  vendor/highline-1.5.1/lib/highline/import.rb
  vendor/highline-1.5.1/lib/highline/menu.rb
  vendor/highline-1.5.1/lib/highline/question.rb
  vendor/highline-1.5.1/lib/highline/system_extensions.rb
  vendor/highline-1.5.1/setup.rb
  vendor/highline-1.5.1/test/tc_color_scheme.rb
  vendor/highline-1.5.1/test/tc_highline.rb
  vendor/highline-1.5.1/test/tc_import.rb
  vendor/highline-1.5.1/test/tc_menu.rb
  vendor/highline-1.5.1/test/ts_all.rb
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