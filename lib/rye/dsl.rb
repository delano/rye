require 'docile'
require 'colorize'


module Rye
  class Box
    def run cmd
      self.instance_exec &@@command[cmd]
    end
  end
  class Set
    def run cmd
      instance_eval &@@command[cmd]
    end
  end
end

@@colors = false || ENV['COLORS'] || ENV['TERM'].match(/.*color.*/)
@hosts, @hostsets, @@command, @contexts = {}, {}, {}, {}
@parallel = nil

def colors state
  @@colors = state
end

def host(hostname, *args, &block)
  @hosts[hostname] = Rye::Box.new(hostname, *args) unless @hosts.key? hostname
  #Docile.dsl_eval(@hosts[hostname], &block) if block_given?
  Docile.dsl_eval(Rye::Set.new.add_box(@hosts[hostname]), &block) if block_given?
end

def hostset(setname, *args, &block)
  @hostsets[setname] = Rye::Set.new(setname) unless @hostsets.key? setname
  args.each do |host|
    @hosts[host] = Rye::Box.new(host) unless @hosts.key? host
    @hostsets[setname].add_box @hosts[host] unless @hostsets[setname].boxes.include? @hosts[host]
  end
  if @parallel
    @hostsets[setname].parallel = true
    Docile.dsl_eval(@hostsets[setname], &block) if block_given?
  else
    @hostsets[setname].boxes.each do |host|
      Docile.dsl_eval(Rye::Set.new.add_box(host), &block) if block_given?
    end
  end
end

def context
end

def command_group(name, &block)
  @@command[name] = Proc.new &block
end

def parallel state
  @parallel = state
end

def colorwrap(msg, color, colorize)
  out = ''
  unless @@colors
    msg.each do |str|
      out += str.to_s.gsub!(/^/, "[#{str.obj.hostname}] ")
    end
  else
    msg.each do |str|
      out += str.to_s.gsub!(/^(.*)$/, "\[#{str.obj.hostname}\] ".cyan + '\1'.send(color)) + "\n"
    end
  end
  out
end

def info(msg, colorize = nil)
  STDOUT.puts colorwrap(msg, :green, @@colors || colorize)
end

def err msg, colorize = nil
  STDOUT.puts colorwrap(msg, :red, @@colors || colorize)
end

def debug msg, colorize = nil
  STDOUT.puts colorwrap(msg, :yellow, @@colors || colorize)
end

