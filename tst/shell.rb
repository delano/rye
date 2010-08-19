require 'net/ssh'
require 'annoy'

#
# For channel requests, see SSH_MSG_CHANNEL_REQUEST messages
# in http://www.snailbook.com/docs/connection.txt
DEBUG = false

module Rye
  class Box
    def debug(state, msg='')
      return unless DEBUG
      puts "   ------ %s: %s" % [state, msg]
    end

    def start_session_state(channel)
      debug :start_session, channel[:handler]
      if channel[:block]
        channel[:state] = :run_block
      else
        channel[:state] = :await_response
      end
    end
    
    def await_response_state(channel)
      debug :await_response, channel[:handler]
      @await_response_counter ||= 0
      if channel[:stdout].available > 0
        channel[:state] = :read_input
      elsif @await_response_counter > 10
        @await_response_counter = 0
        channel[:state] = :await_input
      end
      @await_response_counter += 1
    end
    
    def read_input_state(channel)
      debug :read_input, channel[:handler]
      if channel[:stdout].available > 0
        print channel[:stdout].read
        
        if channel[:stack].empty?
          channel[:state] = :await_input
        elsif channel[:stdout].available > 0
          channel[:state] = :read_input
        else
          channel[:state] = :send_data
        end
      else 
        channel[:state] = :await_response
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
        if channel[:stdout].available > 0
          channel[:state] = :read_input
        else
          if channel[:prompt]
            puts channel[:prompt]
            channel[:prompt] = nil
          end
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
    
    def ignore_response_state(channel)
      debug :ignore_response, channel[:handler]
      @ignore_response_counter ||= 0
      if channel[:stdout].available > 0
        @await_response_counter = 0
        channel[:stdout].read
        channel[:state] = :process
      elsif @ignore_response_counter > 2
        @await_response_counter = 0
        channel[:state] = :process
      end
      @ignore_response_counter += 1
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
    

    def run_block_state(channel)
      debug :run_block, channel[:handler]
      channel[:state] = nil
      blk = channel[:block]
      channel[:block] = nil
      instance_eval &blk
      channel[:state] = :exit
    end

    def command(name,*args, &blk)
      #debug :command, "(#{channel[:handler]})"
      #if channel.eof?
      #  p [:channel_eof]
      #end
      cmd = "%s %s" % [name, args.join(' ')]
      debug :command, "Running: #{cmd}"
      
      pty_opts =   { :term => "xterm",
                              :chars_wide  => 80,
                              :chars_high  => 24,
                              :pixels_wide => 640,
                              :pixels_high => 480,
                              :modes       => {} }
                              
      channel = @session.open_channel do |channel|
        channel.request_pty(pty_opts) do |ch,success|
          self.pty = success
          raise "pty request denied" unless success
        end
        channel.exec(cmd, &create_channel)
        channel[:state] = :start_session
      end
      
      @session.loop(0.1) do
        break if channel.nil? || !channel.active?
        !channel.eof?   # otherwise keep returning true
      end
      
      channel[:stdout].read
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
  
    def run(shell=nil, &blk)
      
      if shell.nil?
        instance_eval &blk
      else
        command(shell)
      end

          
    end
    
    def stop
      @control.join if @control
      @ssh.running = false
      @ssh.close
    end
    
    private
    
    def create_channel()
      Proc.new do |channel,success|
        channel[:stdout  ] = Net::SSH::Buffer.new
        channel[:stderr  ] = Net::SSH::Buffer.new
        channel[:stack] ||= []
        channel.on_close                  { |ch|  
          channel[:handler] = ":on_close"
        }
        channel.on_data                   { |ch, data| 
          channel[:handler] = ":on_data"
          if self.pty && data =~ /\Apassword/i
            channel[:prompt] = data
            channel[:state] = :await_input
          else
            channel[:stdout].append(data) 
          end
        }
        channel.on_extended_data          { |ch, type, data| 
          channel[:handler] = ":on_extended_data"
          channel[:stderr].append(data)
          channel[:state] = :handle_error 
        }
        channel.on_request("exit-status") { |ch, data| 
          channel[:handler] = ":on_request (exit-status)"
          channel[:exit_status] = data.read_long 
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
  rbox.connect 'localhost', 'delano', :verbose => :fatal, :keys => []
  
  rbox.run 'bash'
  #rbox.run do
  #  puts command("date")
  #  puts command("SUDO_PS1=POOP\n")
  #  #puts command("echo $GLORIA_HOME; echo $?")
  #  #puts command("sudo whoami")
  #  #puts command("sudo -k")
  #  
  #  command("cpan")
  #  puts command("uptime")
  #  #puts command("SUDO_PS1='POOP'")
  #  #puts command("echo $SUDO_PS1")
  #  ##puts sudo( 'chroot', '/mnt/archlinux-x86_64')
  #  #command("unset PS1;")
  #end
  #puts rbox.channel[:stderr] if rbox.channel[:stderr]
end


__END__
http://tldp.org/LDP/abs/html/intandnonint.html
case $- in
*i*)    # interactive shell
;;
*)      # non-interactive shell
;;
# (Courtesy of "UNIX F.A.Q.," 1993)