require 'docile'

@hosts, @hostsets, @commands, @contexts = {}, {}, {}, {}
@parallel = false

def host(hostname, *args, &block)
  @hosts[hostname] = Rye::Box.new(hostname, *args)
  Docile.dsl_eval(@hosts[hostname], &block) if block_given?
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
      Docile.dsl_eval(host, &block) if block_given?
    end
  end
end

def context
end

def command
end

def parallel state
  @parallel = state
end

def info msg
  STDOUT.puts msg
end

