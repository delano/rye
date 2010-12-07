# escape.rb - escape/unescape library for several formats
#
# Copyright (C) 2006,2007 Tanaka Akira  <akr@fsij.org>
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#  1. Redistributions of source code must retain the above copyright notice, this
#     list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#  3. The name of the author may not be used to endorse or promote products
#     derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
# EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.

# Escape module provides several escape functions.
# * URI
# * HTML
# * shell command
module Escape # :nodoc:all
  module_function

  class StringWrapper # :nodoc:all
    class << self
      alias new_no_dup new
      def new(str)
        new_no_dup(str.dup)
      end
    end

    def initialize(str)
      @str = str
    end

    def to_s
      @str.dup
    end

    def inspect
      "\#<#{self.class}: #{@str}>"
    end

    def ==(other)
      other.class == self.class && @str == other.instance_variable_get(:@str)
    end
    alias eql? ==

    def hash
      @str.hash
    end
  end

  class ShellEscaped < StringWrapper #:nodoc:all
  end

  # Escape.shell_command composes
  # a sequence of words to
  # a single shell command line.
  # All shell meta characters are quoted and
  # the words are concatenated with interleaving space.
  # It returns an instance of ShellEscaped.
  #
  #  Escape.shell_command(["ls", "/"]) #=> #<Escape::ShellEscaped: ls />
  #  Escape.shell_command(["echo", "*"]) #=> #<Escape::ShellEscaped: echo '*'>
  #
  # Note that system(*command) and
  # system(Escape.shell_command(command)) is roughly same.
  # There are two exception as follows.
  # * The first is that the later may invokes /bin/sh.
  # * The second is an interpretation of an array with only one element: 
  #   the element is parsed by the shell with the former but
  #   it is recognized as single word with the later.
  #   For example, system(*["echo foo"]) invokes echo command with an argument "foo".
  #   But system(Escape.shell_command(["echo foo"])) invokes "echo foo" command without arguments (and it probably fails).
  def shell_command(*command)
    command = [command].flatten.compact # Delano
    s = command.map {|word| shell_single_word(word) }.join(' ')
    ShellEscaped.new_no_dup(s)
  end

  # Escape.shell_single_word quotes shell meta characters.
  # It returns an instance of ShellEscaped.
  #
  # The result string is always single shell word, even if
  # the argument is "".
  # Escape.shell_single_word("") returns #<Escape::ShellEscaped: ''>.
  #
  #  Escape.shell_single_word("") #=> #<Escape::ShellEscaped: ''>
  #  Escape.shell_single_word("foo") #=> #<Escape::ShellEscaped: foo>
  #  Escape.shell_single_word("*") #=> #<Escape::ShellEscaped: '*'>
  def shell_single_word(str)
    return unless str
    str &&= str.to_s # Delano fix
    if str.empty?
      ShellEscaped.new_no_dup("''")
    elsif %r{\A[0-9A-Za-z+,./:=@_-]+\z} =~ str
      ShellEscaped.new(str)
    else
      result = ''
      str.scan(/('+)|[^']+/) {
        if $1
          result << %q{\'} * $1.length
        else
          result << "'#{$&}'"
        end
      }
      ShellEscaped.new_no_dup(result)
    end
  end

  class PercentEncoded < StringWrapper #:nodoc:all
  end

  # Escape.uri_segment escapes URI segment using percent-encoding.
  # It returns an instance of PercentEncoded.
  #
  #  Escape.uri_segment("a/b") #=> #<Escape::PercentEncoded: a%2Fb>
  #
  # The segment is "/"-splitted element after authority before query in URI, as follows.
  #
  #   scheme://authority/segment1/segment2/.../segmentN?query#fragment
  #
  # See RFC 3986 for details of URI.
  def uri_segment(str)
    # pchar - pct-encoded = unreserved / sub-delims / ":" / "@"
    # unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
    # sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
    s = str.gsub(%r{[^A-Za-z0-9\-._~!$&'()*+,;=:@]}n) {
      '%' + $&.unpack("H2")[0].upcase
    }
    PercentEncoded.new_no_dup(s)
  end

  # Escape.uri_path escapes URI path using percent-encoding.
  # The given path should be a sequence of (non-escaped) segments separated by "/".
  # The segments cannot contains "/".
  # It returns an instance of PercentEncoded.
  #
  #  Escape.uri_path("a/b/c") #=> #<Escape::PercentEncoded: a/b/c>
  #  Escape.uri_path("a?b/c?d/e?f") #=> #<Escape::PercentEncoded: a%3Fb/c%3Fd/e%3Ff>
  #
  # The path is the part after authority before query in URI, as follows.
  #
  #   scheme://authority/path#fragment
  #
  # See RFC 3986 for details of URI.
  #
  # Note that this function is not appropriate to convert OS path to URI.
  def uri_path(str)
    s = str.gsub(%r{[^/]+}n) { uri_segment($&) }
    PercentEncoded.new_no_dup(s)
  end

  def html_form_fast(pairs, sep='&')
    s = pairs.map {|k, v|
      # query-chars - pct-encoded - x-www-form-urlencoded-delimiters =
      #   unreserved / "!" / "$" / "'" / "(" / ")" / "*" / "," / ":" / "@" / "/" / "?"
      # query-char - pct-encoded = unreserved / sub-delims / ":" / "@" / "/" / "?"
      # query-char = pchar / "/" / "?" = unreserved / pct-encoded / sub-delims / ":" / "@" / "/" / "?"
      # unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
      # sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
      # x-www-form-urlencoded-delimiters = "&" / "+" / ";" / "="
      k = k.gsub(%r{[^0-9A-Za-z\-\._~:/?@!\$'()*,]}n) {
        '%' + $&.unpack("H2")[0].upcase
      }
      v = v.gsub(%r{[^0-9A-Za-z\-\._~:/?@!\$'()*,]}n) {
        '%' + $&.unpack("H2")[0].upcase
      }
      "#{k}=#{v}"
    }.join(sep)
    PercentEncoded.new_no_dup(s)
  end

  # Escape.html_form composes HTML form key-value pairs as a x-www-form-urlencoded encoded string.
  # It returns an instance of PercentEncoded.
  #
  # Escape.html_form takes an array of pair of strings or
  # an hash from string to string.
  #
  #  Escape.html_form([["a","b"], ["c","d"]]) #=> #<Escape::PercentEncoded: a=b&c=d>
  #  Escape.html_form({"a"=>"b", "c"=>"d"}) #=> #<Escape::PercentEncoded: a=b&c=d>
  #
  # In the array form, it is possible to use same key more than once.
  # (It is required for a HTML form which contains
  # checkboxes and select element with multiple attribute.)
  #
  #  Escape.html_form([["k","1"], ["k","2"]]) #=> #<Escape::PercentEncoded: k=1&k=2>
  #
  # If the strings contains characters which must be escaped in x-www-form-urlencoded,
  # they are escaped using %-encoding.
  #
  #  Escape.html_form([["k=","&;="]]) #=> #<Escape::PercentEncoded: k%3D=%26%3B%3D>
  #
  # The separator can be specified by the optional second argument.
  #
  #  Escape.html_form([["a","b"], ["c","d"]], ";") #=> #<Escape::PercentEncoded: a=b;c=d>
  #
  # See HTML 4.01 for details.
  def html_form(pairs, sep='&')
    r = ''
    first = true
    pairs.each {|k, v|
      # query-chars - pct-encoded - x-www-form-urlencoded-delimiters =
      #   unreserved / "!" / "$" / "'" / "(" / ")" / "*" / "," / ":" / "@" / "/" / "?"
      # query-char - pct-encoded = unreserved / sub-delims / ":" / "@" / "/" / "?"
      # query-char = pchar / "/" / "?" = unreserved / pct-encoded / sub-delims / ":" / "@" / "/" / "?"
      # unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
      # sub-delims = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
      # x-www-form-urlencoded-delimiters = "&" / "+" / ";" / "="
      r << sep if !first
      first = false
      k.each_byte {|byte|
        ch = byte.chr
        if %r{[^0-9A-Za-z\-\._~:/?@!\$'()*,]}n =~ ch
          r << "%" << ch.unpack("H2")[0].upcase
        else
          r << ch
        end
      }
      r << '='
      v.each_byte {|byte|
        ch = byte.chr
        if %r{[^0-9A-Za-z\-\._~:/?@!\$'()*,]}n =~ ch
          r << "%" << ch.unpack("H2")[0].upcase
        else
          r << ch
        end
      }
    }
    PercentEncoded.new_no_dup(r)
  end

  class HTMLEscaped < StringWrapper #:nodoc:all
  end

  HTML_TEXT_ESCAPE_HASH = {
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
  }


  # Escape.html_text escapes a string appropriate for HTML text using character references.
  # It returns an instance of HTMLEscaped.
  #
  # It escapes 3 characters:
  # * '&' to '&amp;'
  # * '<' to '&lt;'
  # * '>' to '&gt;'
  #
  #  Escape.html_text("abc") #=> #<Escape::HTMLEscaped: abc>
  #  Escape.html_text("a & b < c > d") #=> #<Escape::HTMLEscaped: a &amp; b &lt; c &gt; d>
  #
  # This function is not appropriate for escaping HTML element attribute
  # because quotes are not escaped.
  def html_text(str) #:nodoc:all
    s = str.gsub(/[&<>]/) {|ch| HTML_TEXT_ESCAPE_HASH[ch] }
    HTMLEscaped.new_no_dup(s)
  end

  HTML_ATTR_ESCAPE_HASH = { #:nodoc:all
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
  }


  class HTMLAttrValue < StringWrapper #:nodoc:all
  end

  # Escape.html_attr_value encodes a string as a double-quoted HTML attribute using character references.
  # It returns an instance of HTMLAttrValue.
  #
  #  Escape.html_attr_value("abc") #=> #<Escape::HTMLAttrValue: "abc">
  #  Escape.html_attr_value("a&b") #=> #<Escape::HTMLAttrValue: "a&amp;b">
  #  Escape.html_attr_value("ab&<>\"c") #=> #<Escape::HTMLAttrValue: "ab&amp;&lt;&gt;&quot;c">
  #  Escape.html_attr_value("a'c") #=> #<Escape::HTMLAttrValue: "a'c">
  #
  # It escapes 4 characters:
  # * '&' to '&amp;'
  # * '<' to '&lt;'
  # * '>' to '&gt;'
  # * '"' to '&quot;'
  #
  def html_attr_value(str) #:nodoc:all
    s = '"' + str.gsub(/[&<>"]/) {|ch| HTML_ATTR_ESCAPE_HASH[ch] } + '"'
    HTMLAttrValue.new_no_dup(s)
  end
end
