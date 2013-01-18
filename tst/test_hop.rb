$: << File.expand_path(Dir.pwd + "/lib")
$:.reverse!

require 'rubygems'
require 'rye'
begin
require 'perftools'
rescue LoadError => ex
    puts ex.message
    puts "$> gem install perftools.rb"
    exit 1
end

data_file       = Dir.pwd + "/profile.data"
pdf_file        = Dir.pwd + "/profile.pdf"
text_file       = Dir.pwd + "/profile.txt"

PerfTools::CpuProfiler.start(data_file) do
  lo0 = Rye::Hop.new "localhost"                # set some real host names
  lo1 = Rye::Box.new "localhost", :via => lo0   # set some real host names
  puts lo1.uptime
end

system("pprof.rb --pdf #{data_file} > #{pdf_file}")
system("pprof.rb --text #{data_file} > #{text_file}")
