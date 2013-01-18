require 'docile'

module Rye
  class Set
    def run cmd
      instance_eval &@@command[cmd]
    end
  end
end

@hosts, @hostsets, @contexts = {}, {}, {}
@parallel = nil

@@colors = false || ENV['COLORS'] || ENV['TERM'].match(/.*color.*/)
@@command = {}

def parallel state; @parallel = state; end
def colors   state; @@colors  = state; end

def host(hostname, *args, &block)
  @hosts[hostname] = Rye::Box.new(hostname, *args) unless @hosts.key? hostname
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

def command_group(name, &block)
  @@command[name] = Proc.new &block
end

def exit_status_check(cmd, opts={})
  enable_quiet_mode
  @pass = opts[:pass_str] || cmd.to_s + ' Passed Status Check'
  @fail = opts[:fail_str] || cmd.to_s + ' Failed Status Check'
  def results(obj, out)
    if obj.exit_status == 0
      info out, :altstring => @pass
    else
      err out, :altstring => @fail
    end
  end
  out = execute cmd
  if out[0].class == Rye::Rap
    out.each do |rap|
      results(rap, out)
    end
  elsif out.exit_status == 0
    results(out, out)
  end
  disable_quiet_mode
end

def strwrap(msg, opts={})
  out = ''
  unless @@colors
    msg.each do |str|
      unless opts.key? :altstring
        out += str.to_s.gsub!(/^/, "[#{str.obj.hostname}] ") + "\n"
      else
        out += "[#{str.obj.hostname}] #{opts[:altstring]}\n"
      end
    end
  else
    msg.each do |str|
      unless opts.key? :altstring
        out += str.to_s.gsub!(/^(.*)$/, str.obj.hostname)
      else
        out += "#{str.obj.hostname} " + opts[:altstring]
      end
    end
  end
  out
end

def info msg, *opts
  STDOUT.puts strwrap(msg, *opts)
end

def err msg, *opts
  STDOUT.puts strwrap(msg, *opts)
end

def debug msg, *opts
  STDOUT.puts strwrap(msg, *opts)
end

