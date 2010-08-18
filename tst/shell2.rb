# process multiple Net::SSH connections in parallel
connections = [
 Net::SSH.start("host1", ...),
 Net::SSH.start("host2", ...)
]

connections.each do |ssh|
 ssh.exec "grep something /in/some/files"
end

condition = Proc.new { |s| s.busy? }

loop do
 connections.delete_if { |ssh| !ssh.process(0.1, &condition) }
 break if connections.empty?
end

@channel = ssh.open_channel do |channel|
  channel.send_channel_request 'shell' 
  channel[:callback] = Proc.new { p :callback }
  channel[:buffer  ] = Net::SSH::Buffer.new
  channel[:batch   ] = blk
  channel[:stderr  ] = Net::SSH::Buffer.new
  channel[:state   ] = "call_command"
  channel[:stack   ] = ['echo $SHELL']
  channel.on_close                  { |ch| raise "Did not finish successfully (#{ch[:exit]})" if ch[:exit] != 0 }
  channel.on_data                   { |ch, data| channel[:buffer].append(data) }
  channel.on_extended_data          { |ch, type, data| channel[:stderr].append(data) }
  channel.on_request("exit-status") { |ch, data| channel[:exit] = data.read_long }
  channel.on_process                { 
    puts channel[:stderr].read if channel[:stderr].available > 0
    send("#{channel[:state]}_state", channel)
  }
  channel.on_request("exit-signal") do |ch, data|
    # This should be the POSIX SIGNAL that ended the process
    channel[:exit_signal] = data.read_long
  end
  instance_eval &blk
end
trap("INT") { 
  p [:INT, @control, ssh.closed?, channel.eof?]
  self.running = false 
  unless ssh.closed?
    ssh.close 
    channel.eof!
  end
  @control.join if @control
}
