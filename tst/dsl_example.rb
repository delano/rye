# vim: filetype=ruby

host '192.168.56.101', :user => 'root' do
  disable_safe_mode
  cd '/'
  info ls '-lah'
end

host '192.168.56.102', :user => 'root'

parallel false

hostset 'virtualbox machines', '192.168.56.101', '192.168.56.102' do
  disable_safe_mode
  disable_quiet_mode
  cd '/root'
  info ls '-lah'
end

hostset 'virtualbox machines' do
  info execute 'ps -Af | grep "getty"'
end

host 'main01', :user => 'root'
host 'test01', :user => 'root'

hostset 'virtualbox machines by hostname', 'main01', 'test01'

parallel true

hostset 'virtualbox machines by hostname' do
  # Since this is a different Rye::Set instance from 'virtualbox machines', it starts from scratch
  # so safe mode has to be disabled again to run ping
  disable_safe_mode
  disable_quiet_mode
  info execute 'ping -c 1 localhost'
end

command_group 'library list' do
  cd '/usr/lib/'
  info ls('-la | head -n 5')
end

command_group 'top five processes' do
  info execute 'ps -Af | head'
end

command_group 'check tunnel' do
  exit_status_check 'ps -Af | grep "ssh -N -f -D 9050" | grep -v "grep"'
end

command_group 'check tmux' do
  # Should pass if tmux is running
  exit_status_check 'ps -Af | grep start-server | grep -v "grep"', 
                    :pass_str => 'Tmux Check Passed', 
                    :fail_str => 'Tmux Check Failed'
  # Should fail
  exit_status_check 'ps -Af | grep "start-serverz" | grep -v "grep"'
end

hostset 'virtualbox machines by hostname' do
  colors false
  run 'library list'
end

colors true

host 'main01' do
  disable_safe_mode
  run 'library list'
  run 'top five processes'
  debug ls '-la /etc | head -n 5'
  run 'check tunnel'
end

host 'localhost' do
  disable_safe_mode
  run 'check tmux'
end

