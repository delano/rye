# vim: set sw=2 ts=2 :

module Rye
  class Key
    class BadFile < RuntimeError
      def initialize(m); @m = m; end
      def message; "That ain't a no key. #{$/}#{@m}"; end
    end
    class BadPerm < RuntimeError
      def initialize(m); @m = m; end
      def message; "Bad file permissions. Set to 0600. #{$/}#{@m}"; end
    end
      
      # A nickname for this key. If a path was specified this defaults to the basename. 
    attr_reader :name
     # Authentication type: RSA or DSA
    attr_reader :authtype
     # Key type: public or private
    attr_reader :keytype
    
    def initialize(data, name=nil)
      @data = data
      @name = name || 'default'
      parse_data
    end  
    
    def self.generate_pkey(authtype="RSA", bits=1024)
      unless Rye::Key.supported_authentication?(authtype)
        raise OpenSSL::PKey::PKeyError, "Unknown authentication: #{authttype}" 
      end
      bits &&= bits.to_i
      klass = authtype.upcase == "RSA" ? OpenSSL::PKey::RSA : OpenSSL::PKey::DSA
      pk = klass.new(bits)
    end
    
    def self.from_file(path)
      raise BadFile, path unless File.exists?(path || '')
      pkey = self.new File.read(path), File.basename(path)
      file_perms = (File.stat(path).mode & 600)
      raise BadPerm, path if file_perms != 0 && pkey.private?
      pkey
    end
    
    
    def sign(string, digesttype="sha1")
      Rye::Key.sign(@keypair.to_s, string, digesttype)
    end
    
    def self.sign(secret, string, digesttype="sha1")
      @@digest ||= {} 
      @@digest[digest] ||= OpenSSL::Digest::Digest.new(digesttype)
      sig = OpenSSL::HMAC.hexdigest(@@digest[digest], secret, string).strip
    end
    def self.sign_aws(secret, string)
      ::Base64.encode64(self.sign(secret, string, "sha1")).strip
    end
    
    def private_key
      raise OpenSSL::PKey::PKeyError, "No private key" if public? || !@keypair
      @keypair.to_s
    end
    
    def public_key
      raise OpenSSL::PKey::PKeyError, "No public key" if !@keypair
      pubkey = public? ? @keypair : @keypair.public_key
      # Add the to_ssh2 method to the instance of OpenSSL::PKey::*SA only
      def pubkey.to_ssh2; Rye::Key.public_key_to_ssh2(self);  end
      pubkey
    end
      
    # Encrypt +text+ with this public or private key. The key must 
    def encrypt(text); ::Base64.encode64(@keypair.send("#{keytype.downcase}_encrypt", text)); end
    def decrypt(text); @keypair.send("#{keytype.downcase}_decrypt", ::Base64.decode64(text)); end
  
    def private?; @keytype.upcase == "PRIVATE"; end              
    def public?; @keytype.upcase == "PUBLIC";  end
    def rsa?; @authtype.upcase == "RSA"; end
    def dsa?; @authtype.upcase == "DSA"; end
    def encrypted?; @data && @data.match(/ENCRYPTED/); end
    
    # * +pubkey+ an instance of OpenSSL::PKey::RSA or OpenSSL::PKey::DSA
    # Returns a public key in SSH format (suitable for ~/.ssh/authorized_keys)
    def self.public_key_to_ssh2(pubkey)
      authtype = pubkey.class.to_s.split('::').last.downcase
      b64pub = ::Base64.encode64(pubkey.to_blob).strip.gsub(/[\r\n]/, '')
      "ssh-%s %s" % [authtype, b64pub]  # => ssh-rsa AAAAB3NzaC1...=
    end
    
    def dump
      puts @keypair.public_key.to_text
      puts @keypair.public_key.to_pem
    end
    
    # Reveals the key basename. Does not print the key. 
    #
    #     <Rye::Key:id_rsa.pub>
    #
    def to_s
      '<%s:%s>' % [self.class.to_s, name]
    end
    
    # Reveals some metadata about the key. Does not print the key. 
    #
    #     <Rye::Key:id_rsa.pub authtype="RSA" keytype="PRIVATE">
    #
    def inspect
      '<%s:%s authtype="%s" keytype="%s">' % [self.class.to_s, name, @authtype, @keytype]
    end
    
    def self.supported_authentication?(val)
      ["RSA", "DSA"].member?(val || '')
    end
    
    def self.supported_keytype?(val)
      ["PRIVATE", "PUBLIC"].member?(val || '')
    end
    
  private
    # Creates an OpenSSL::PKey object from +@data+.
    def parse_data
      # NOTE: Don't print @data. Not even in debug output. The same goes for +@keypair+.
      # We don't want private keys to end up somewhere we don't expect them. 
      raise OpenSSL::PKey::PKeyError, "No key data" if @data.nil? 
      @data.strip!
      @data =~ /\A-----BEGIN (\w+?) (P\w+?) KEY-----$/  # \A matches the string beginning (^ works on lines)
      raise OpenSSL::PKey::PKeyError, "Bad key data" unless $1 && $2
      raise OpenSSL::PKey::PKeyError, "Unknown type #{$1}" unless Rye::Key.supported_authentication?($1)
      raise OpenSSL::PKey::PKeyError, "Unknown value #{$2}" unless Rye::Key.supported_keytype?($2)
      @authtype, @keytype = $1, $2
      @keypair = OpenSSL::PKey::RSA.new(@data) if self.rsa?
      @keypair = OpenSSL::PKey::DSA.new(@data) if self.dsa?
    end
    
  end
end
