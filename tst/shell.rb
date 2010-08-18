require 'net/ssh'

#
# For channel requests, see SSH_MSG_CHANNEL_REQUEST messages
# in http://www.snailbook.com/docs/connection.txt
DEBUG = true

module Rye
  class Box
    def debug(state, msg)
      return unless DEBUG
      puts "   ------ %s: %s" % [state, msg]
    end

    def call_command_state(channel)
      debug :call_command, channel.object_id
      unless channel[:stack].empty?
        cmd = channel[:stack].shift
        puts "calling #{cmd.inspect}"
        channel[:state] = :await_response
        channel.send_data("#{cmd}\n") 
      end
    end

    def read_input_state(channel)
      debug :read_input, channel.object_id
      puts channel[:buffer].read
      if channel[:buffer].available > 0
        #channel[:buffer].read
      else 
        channel[:state] = :await_response
      end
      if channel[:stack].empty?
        channel.eof!
      else
        channel[:state] = :call_command
      end
      channel[:state] = :call_command
    end

    def await_response_state(channel)
      debug :await_response, channel.object_id
      return if channel[:buffer].available == 0
      channel[:state] = channel[:block] ? :run_block : :read_input
    end
    
    def run_block_state(channel)
      instance_eval &channel[:block]
      channel[:block] = nil
      channel[:state] = :await_response
    end

    def command(name,*args, &blk)
      channel[:state] = :await_response
      channel[:block] = blk
      cmd = "%s %s" % [name, args.join(' ')]
      channel.send_data("#{cmd}\n")

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
      
    attr_reader :ssh, :channel
    attr_accessor :running
    
    def connect 
      opts = {}
      @sessions ||= []
      @session = Net::SSH.start('localhost', 'delano', opts) 
    end
  
    def run(&blk)
      
      @session.process(0.1, &busy_proc)
      
      result = nil
      @channel = @session.open_channel do |ch|
        ch.exec("irb") do |c, success|
          ch.on_data { |c, data| puts data }
          ch.on_extended_data { |c, type, data| puts data }
          ch.on_close { |c| c.close }
        end
      end
      
      
      @channel.send_data("require 'gibbler' \n")
      @channel.send_data("{}.gibbler\n")
      @channel.send_data("exit\n")
      
      @session.loop

      
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
  end
end

begin
  puts $$
  rbox = Rye::Box.new
  rbox.connect
  rbox.run 
  
  #p rbox.channel[:exit], rbox.channel[:exit_signal]

end
