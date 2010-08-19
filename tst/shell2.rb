require 'net/ssh'

#
# For channel requests, see SSH_MSG_CHANNEL_REQUEST messages
# in http://www.snailbook.com/docs/connection.txt
DEBUG = true

module Rye
  class Box
    def debug(state, msg='')
      return unless DEBUG
      puts "   ------ %s: %s" % [state, msg]
    end

    def start_session_state(channel)
      debug :start_session, channel[:handler]
      channel.send_data("unset PS1; stty -echo\n")
      channel[:state] = :ignore_response
    end
    
    def ignore_response_state(channel)
      debug :ignore_response, channel[:handler]
      @ignore_response_counter ||= 0
      if channel[:buffer].available > 0
        @await_response_counter = 0
        channel[:buffer].read
        channel[:state] = :process
      elsif @ignore_response_counter > 2
        @await_response_counter = 0
        channel[:state] = :process
      end
      @ignore_response_counter += 1
    end
    
    def process_state(channel)
      debug :process, channel[:handler]
      if channel[:block]
        channel[:state] = :run_block
      else
        channel[:state] = :await_input
      end
    end
    
    def send_data_state(channel)
      debug :send_data, channel[:handler]
      #if channel[:stack].empty?
      #  channel[:state] = :await_input
      #else
        cmd = channel[:stack].shift
        #return if cmd.strip.empty?
        debug :send_data, "calling #{cmd.inspect}"
        channel[:state] = :await_response
        channel.send_data("#{cmd}\n") unless channel.eof?
        #channel.exec("#{cmd}\n", &create_channel) 
      #end
    end
    
    def await_input_state(channel)
      debug :await_input, channel[:handler]
      
        if channel[:buffer].available > 0
          channel[:state] = :read_input
        else
          ret = STDIN.gets
          if ret.nil?
            channel.eof!
            channel[:state] = :exit
          else
            channel[:stack] << ret.chomp
            channel[:state] = :send_data
          end
        end
        
    end
    
    def check_interactive_state(channel)
      debug :read_input, channel[:handler]
      channel.send_data("x")
    end
    
    def read_input_state(channel)
      debug :read_input, channel[:handler]
      if channel[:buffer].available > 0
        print channel[:buffer].read
        
        if channel[:stack].empty?
          channel[:state] = :await_input
        elsif channel[:buffer].available > 0
          channel[:state] = :read_input
        else
          channel[:state] = :send_data
        end
      else 
        channel[:state] = :await_response
      end
    end
    
    def exit_state(channel)
      debug :exit_state, channel[:exit_status]
      puts
      channel.eof!
    end
    
    def handle_error_state(channel)
      debug :handle_error, channel[:handler]
      channel.eof!
    end
    

    def await_response_state(channel)
      debug :await_response, channel[:handler]
      @await_response_counter ||= 0
      if channel[:buffer].available > 0
        channel[:state] = :read_input
      elsif @await_response_counter > 20
        @await_response_counter = 0
        channel[:state] = :await_input
      end
      @await_response_counter += 1
    end
    
    def run_block_state(channel)
      debug :run_block, channel[:handler]
      channel[:state] = nil
      blk = channel[:block]
      channel[:block] = nil
      instance_eval &blk
      channel[:state] = :exit
    end

    def command(name,*args, &blk)
      debug :command, channel[:handler]
      return if @channel.eof?
      cmd = "%s %s" % [name, args.join(' ')]
      debug :command, "Running: #{cmd}"
      if self.pty && channel[:buffer].available
        prompt = channel[:buffer].read 
      end
        channel.send_data("#{cmd}\n")
        channel.connection.loop do 
          break if channel[:buffer].available > 0
          p :loop
          channel.active?
        end
        ret = channel[:buffer].read
        ret
      
    end
    
    def wait_for_command_state(channel)
      debug :wait_for_command, channel[:handler]
    end
    
    def ls(*args) command(:ls, *args) end
    def cat(*args) command(:cat, *args) end
      def echo(*args) command(:echo, *args) end
    def sudo(*args) command(:sudo, *args) end
    def date(*args) command(:date, *args) end
    def uname(*args) command(:uname, *args) end
    def chroot(*args) command(:chroot, *args) end
    def bash(*args, &blk) command(:bash, *args, &blk) end
    def exit(*args, &blk) command(:exit, *args, &blk) end
      
    attr_reader :session, :channel
    attr_accessor :running, :pty
    
    def connect(host, user, opts={})
      opts = {
        :auth_methods => %w[keyboard-interactive]
      }.merge(opts)
      opts[:auth_methods].unshift 'publickey' unless opts[:keys].nil?
      opts[:auth_methods].unshift 'password' unless opts[:password].nil?
      @sessions ||= []
      @session = Net::SSH.start(host, user, opts) 
    end
  
    def run(shell, &blk)
      
      puts "Running #{shell}"
      @channel = @session.open_channel do |channel|
        #if blk.nil?
          channel.request_pty do |ch,success|
            self.pty = success
            raise "pty request denied" unless success
          end
        #end
        channel.exec shell, &create_channel
      end
      
      channel[:block] = blk
      
      @session.loop(0.5) do
        break if !@channel.active?
        !@channel.eof?   # otherwise keep returning true
      end
      
    end
    
    def stop
      @control.join if @control
      @ssh.running = false
      @ssh.close
    end
    
    private
    def busy_proc
      Proc.new { |s| !s.busy? }
    end
    
    def create_channel
      Proc.new do |channel,success|
        channel[:callback] = Proc.new { p :callback }
        channel[:buffer  ] = Net::SSH::Buffer.new
        #channel[:batch   ] = blk
        channel[:stderr  ] = Net::SSH::Buffer.new
        channel[:state   ] = "start_session"
        @channel[:stack] ||= []
        channel.on_close                  { |ch|  
          channel[:handler] = ":on_close"
        }
        channel.on_data                   { |ch, data| 
          channel[:handler] = ":on_data"
          channel[:buffer].append(data) 
        }
        channel.on_extended_data          { |ch, type, data| 
          channel[:handler] = ":on_extended_data"
          channel[:stderr].append(data)
          channel[:state] = :handle_error 
        }
        channel.on_request("exit-status") { |ch, data| 
          channel[:handler] = ":on_request (exit-status)"
          channel[:exit] = data.read_long 
        }
        channel.on_request("exit-signal") do |ch, data|
          channel[:handler] = ":on_request (exit-signal)"
          # This should be the POSIX SIGNAL that ended the process
          channel[:exit_signal] = data.read_long
        end
        channel.on_process                { 
          channel[:handler] = :on_process
          print channel[:stderr].read if channel[:stderr].available > 0
          begin
            send("#{channel[:state]}_state", channel) unless channel[:state].nil?
          rescue Interrupt
            debug :await_input_interrupt
            channel[:state] = :exit
          end
        }
      end
    end
  end
end

begin
  puts $$
  rbox = Rye::Box.new
  rbox.connect 'ec2-184-72-169-231.compute-1.amazonaws.com', 'ubuntu', :verbose => :fatal, :keys => ['~/.ssh/key-us-east-1b-build-arch']
  #rbox.run 'bash'
  rbox.run 'bash' do
    puts command("date")
    p cat("/etc/issue")
    command("SUDO_PS1=''")
    puts sudo( 'chroot', '/mnt/archlinux-x86_64')
    command("unset PS1;")
    p cat("/etc/issue")
  end
  puts rbox.channel[:stderr] if rbox.channel[:stderr]
end


__END__
http://tldp.org/LDP/abs/html/intandnonint.html
case $- in
*i*)    # interactive shell
;;
*)      # non-interactive shell
;;
# (Courtesy of "UNIX F.A.Q.," 1993)