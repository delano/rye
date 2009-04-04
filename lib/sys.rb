require 'socket'

# SystemInfo
# 
# A container for the platform specific system information. 
# Portions of this code were originally from Amazon's EC2 AMI tools, 
# specifically lib/platform.rb. 
class SystemInfo
  VERSION = 2
  IMPLEMENTATIONS = [
    
    # These are for JRuby, System.getproperty('os.name'). 
    # For a list of all values, see: http://lopica.sourceforge.net/os.html
    [/mac\s*os\s*x/i,     :unix,    :osx     ],  
    [/sunos/i,            :unix,    :solaris ], 
    [/windows\s*ce/i,     :win32,   :windows ],
    [/windows/i,          :win32,   :windows ],  
    [/osx/i,              :unix,    :osx     ],
    
    # TODO: implement other windows matches: # /djgpp|(cyg|ms|bcc)win|mingw/ (from mongrel)
    
    # These are for RUBY_PLATFORM and JRuby
    [/java/i,    :java,    :java             ],
    [/darwin/i,  :unix,    :osx              ],
    [/linux/i,   :unix,    :linux            ],
    [/freebsd/i, :unix,    :freebsd          ],
    [/netbsd/i,  :unix,    :netbsd           ],
    [/solaris/i, :unix,    :solaris          ],
    [/irix/i,    :unix,    :irix             ],
    [/cygwin/i,  :unix,    :cygwin           ],
    [/mswin/i,   :win32,   :windows          ],
    [/mingw/i,   :win32,   :mingw            ],
    [/bccwin/i,  :win32,   :bccwin           ],
    [/wince/i,   :win32,   :wince            ],
    [/vms/i,     :vms,     :vms              ],
    [/os2/i,     :os2,     :os2              ],
    [nil,        :unknown, :unknown          ],
    
  ]

  ARCHITECTURES = [
    [/(i\d86)/i,  :i386             ],
    [/x86_64/i,   :x86_64           ],
    [/x86/i,      :i386             ],  # JRuby
    [/ia64/i,     :ia64             ],
    [/alpha/i,    :alpha            ],
    [/sparc/i,    :sparc            ],
    [/mips/i,     :mips             ],
    [/powerpc/i,  :powerpc          ],
    [/universal/i,:universal        ],
    [nil,         :unknown          ],
  ]
  


  attr_reader :os 
  attr_reader :implementation
  attr_reader :architecture 
  attr_reader :hostname 
  attr_reader :ipaddress 
  attr_reader :uptime 
  
  
  alias :impl :implementation
  alias :arch :architecture

  
  def initialize
    @os, @implementation, @architecture = guess
    @hostname, @ipaddress, @uptime = get_info
  end
  
  # guess
  #
  # This is called at require-time in stella.rb. It guesses
  # the current operating system, implementation, architecture. 
  # Returns [os, impl, arch]
  def guess
    os = :unknown
    impl = :unknown
    arch = :unknown
    IMPLEMENTATIONS.each do |r, o, i|
      if r and RUBY_PLATFORM =~ r
        os, impl = [o, i]
        break
      end
    end
    ARCHITECTURES.each do |r, a|
      if r and RUBY_PLATFORM =~ r
        arch = a
        break
      end
    end
    
    #
    if os == :win32
      #require 'Win32API'

    # If we're running in java, we'll need to look elsewhere
    # for the implementation and architecture. 
    # We'll replace IMPL and ARCH with what we find. 
    elsif os == :java
      require 'java'
      include_class java.lang.System
      
      osname = System.getProperty("os.name")
      IMPLEMENTATIONS.each do |r, o, i|
        if r and osname =~ r
          impl = i
          break
        end
      end
      
      osarch = System.getProperty("os.arch")
      ARCHITECTURES.each do |r, a|
        if r and osarch =~ r
          arch = a
          break
        end
      end
      
    end

    [os, impl, arch]
  end

  # get_info
  #
  # Returns [hostname, ipaddr, uptime] for the local machine
  def get_info
    hostname = :unknown
    ipaddr = :unknown
    uptime = :unknown

    begin
      hostname = local_hostname
      ipaddr = local_ip_address
      uptime = local_uptime       
    rescue => ex
      # Be silent!
    end

    [hostname, ipaddr, uptime]
  end

  # local_hostname
  #
  # Return the hostname for the local machine
  def local_hostname
    Socket.gethostname
  end
  
  # local_uptime
  #
  # Returns the local uptime in hours. Use Win32API in Windows, 
  # 'sysctl -b kern.boottime' os osx, and 'who -b' on unix.
  # Based on Ruby Quiz solutions by: Matthias Reitinger 
  # On Windows, see also: net statistics server
  def local_uptime

    # Each method must return uptime in seconds
    methods = {

      :win32_windows => lambda {
        # Win32API is required in self.guess
        getTickCount = Win32API.new("kernel32", "GetTickCount", nil, 'L')
        ((getTickCount.call()).to_f / 1000).to_f
      },

      # Ya, this is kinda wack. Ruby -> Java -> Kernel32. See:
      # http://www.oreillynet.com/ruby/blog/2008/01/jruby_meets_the_windows_api_1.html
      # http://msdn.microsoft.com/en-us/library/ms724408(VS.85).aspx
      # Ruby 1.9.1: Win32API is now deprecated in favor of using the DL library.
      :java_windows => lambda {
        kernel32 = com.sun.jna.NativeLibrary.getInstance('kernel32')
        buf = java.nio.ByteBuffer.allocate(256)
        (kernel32.getFunction('GetTickCount').invokeInt([256, buf].to_java).to_f / 1000).to_f 
      },
      
      :unix_osx => lambda {
        # This is faster than who and could work on BSD also. 
        (Time.now.to_f - Time.at(`sysctl -b kern.boottime 2>/dev/null`.unpack('L').first).to_f).to_f
      },
      # This should work for most unix flavours. 
      :unix => lambda {
        # who is sloooooow. Use File.read('/proc/uptime')
        (Time.now.to_f - Time.parse(`who -b 2>/dev/null`).to_f)
      }
    }

    hours = 0
    
    begin
      key = platform
      method = (methods.has_key? key) ? methods[key] : methods[:unix]
      hours = (method.call) / 3600 # seconds to hours
    rescue => ex
    end
    hours
  end


  #
  # Return the local IP address which receives external traffic
  # from: http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
  # NOTE: This <em>does not</em> open a connection to the IP address. 
  def local_ip_address
    # turn off reverse DNS resolution temporarily 
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true   
    UDPSocket.open {|s| s.connect('75.101.137.7', 1); s.addr.last } # Solutious IP
  ensure  
    Socket.do_not_reverse_lookup = orig
  end

  #
  # Returns the local IP address based on the hostname. 
  # According to coderrr (see comments on blog link above), this implementation
  # doesn't guarantee that it will return the address for the interface external
  # traffic goes through. It's also possible the hostname isn't resolvable to the
  # local IP.  
  def local_ip_address_alt
    ipaddr = :unknown
    begin
      saddr = Socket.getaddrinfo(  Socket.gethostname, nil, Socket::AF_UNSPEC, Socket::SOCK_STREAM, nil, Socket::AI_CANONNAME)
      ipaddr = saddr.select{|type| type[0] == 'AF_INET' }[0][3]
    rescue => ex
    end
    ipaddr
  end

  # returns a symbol in the form: os_implementation. This is used throughout Stella
  # for platform specific support. 
  def platform
    "#{@os}_#{@implementation}".to_sym
  end
  
  # Returns Ruby version as an array
  def ruby
    RUBY_VERSION.split('.').map { |v| v.to_i }
  end
  
  # Returns the environment PATH as an Array
  def paths
    if @os == :unix
      (ENV['PATH'] || '').split(':')
    elsif
      (ENV['PATH'] || '').split(';') # Note tested!
    else
      raise "paths not implemented for: #{@os}"
    end
  end
  
  def user
    ENV['USER']
  end
  
  def home
    if @os == :unix
      File.expand_path(ENV['HOME'])
    elsif @os == :win32
      File.expand_path(ENV['USERPROFILE'])
    else
      raise "paths not implemented for: #{@os}"
    end
  end
  
  # Print friendly system information. 
  def to_s
    sprintf("Hostname: %s#{$/}IP Address: %s#{$/}System: %s#{$/}Uptime: %.2f (hours)#{$/}Ruby: #{ruby.join('.')}", 
      @hostname, @ipaddress, "#{@os}-#{@implementation}-#{@architecture}", @uptime)
  end
  
  
end
