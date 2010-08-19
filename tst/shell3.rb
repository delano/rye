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
      #channel.send_data("stty -echo\n")
      #channel[:state] = :ignore_response
      channel[:state] = :await_response
    end
    
    def await_response_state(channel)
      debug :await_response, channel[:handler]
      @await_response_counter ||= 0
      if channel[:buffer].available > 0
        channel[:state] = :read_input
      elsif @await_response_counter > 10
        @await_response_counter = 0
        channel[:state] = :await_input
      end
      @await_response_counter += 1
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
    
    def exit_state(channel)
      debug :exit_state, channel[:exit_status]
      puts
      channel.eof!
    end
    
    def handle_error_state(channel)
      debug :handle_error, channel[:handler]
      channel.eof!
    end
    
    def ignore_response_state(channel)
      debug :ignore_response, channel[:handler]
      @ignore_response_counter ||= 0
      if channel[:buffer].available > 0
        @await_response_counter = 0
        channel[:buffer].read
        channel[:state] = :await_input
      elsif @ignore_response_counter > 2
        @await_response_counter = 0
        channel[:state] = :await_input
      end
      @ignore_response_counter += 1
    end
    

    def run_block_state(channel)
      instance_eval &channel[:block]
      channel[:block] = nil
      channel[:state] = :await_response
    end

    def command(name,*args, &blk)
      return if @channel.eof?
      channel[:block] = blk
      cmd = "%s %s" % [name, args.join(' ')]
      channel.send_data("#{cmd}\n")
      #channel.wait
      channel[:state] = :await_response
      
      #@channel[:buffer]
      #   channel.exec "ls -l /home" do |ch, success|
      #     if success
      #       puts "command has begun executing..."
      #       # this is a good place to hang callbacks like #on_data...
      #     else
      #       puts "alas! the command could not be invoked!"
      #     end
      #   end
    end

    def ls(*args) command(:ls, *args) end
    def date(*args) command(:date, *args) end
    def bash(*args, &blk) command(:bash, *args, &blk) end
    def exit(*args, &blk) command(:exit, *args, &blk) end
      
    attr_reader :session, :channel
    attr_accessor :running
    
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
      
      #@session.process(0.1, &busy_proc)
      
      #result = nil
      #@channel = @session.open_channel do |ch|
      #  ch.exec("irb") do |c, success|
      #    ch.on_data { |c, data| puts data }
      #    ch.on_extended_data { |c, type, data| puts data }
      #    ch.on_close { |c| c.close }
      #  end
      #end
      
      @channel = @session.open_channel do |channel|
        channel.request_pty do |ch,success|
          if success
            
          else
            raise "pty request denied"
          end
        end
        channel.exec shell, &create_channel
      end
      
      
      @channel[:stack] ||= []
      #@channel[:stack] << "require 'gibbler'"
      #@channel[:stack] << "{}.gibbler"

      #trap("INT") { 
      #  p [:INT, @session.closed?, @channel.eof?]
      #  #if channel[:state] == :await_input
      #  @channel.eof!
      #  @session.close unless @session.closed?
      #}
      #trap("INT") { 
        #@channel.eof! unless @channel.eof?
        #@session.close unless @session.closed?
      #  @channel[:state] = :exit
      #}

      @session.loop(0.1) do
        break if !@channel.active?
        !@channel.eof?   # otherwise keep returning true
      end
      
      #puts @channel[:stderr], @channel[:exit_status]
      
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
            send("#{channel[:state]}_state", channel)
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
  rbox.connect 'localhost', 'delano', :keys => []
  rbox.run 'bash'
  
  #p rbox.channel[:exit], rbox.channel[:exit_signal]

end


__END__
http://tldp.org/LDP/abs/html/intandnonint.html
case $- in
*i*)    # interactive shell
;;
*)      # non-interactive shell
;;
# (Courtesy of "UNIX F.A.Q.," 1993)