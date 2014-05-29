# = uri/mailto.rb
#
# Author:: Akira Yamada <akira@ruby-lang.org>
# License:: You can redistribute it and/or modify it under the same term as Ruby.
# Revision:: $Id: mailto.rb 34360 2012-01-23 08:12:52Z naruse $
#
# See URI for general documentation
#

require 'uri/generic'

module URI

  #
  # RFC3261, The sip URL scheme
  #
  class SIP < Generic
    include REGEXP

    # A Default port of nil for URI::SIP
    DEFAULT_PORT = nil

    # An Array of the available components for URI::SIP
    COMPONENT = [ :scheme, :user, :host, :port, :parameters, :headers ].freeze

    # :stopdoc:
    #  "hname" and "hvalue" are encodings of an RFC 3261 header name and
    #  value, respectively. All URL reserved characters must
    #  be encoded.
    #
    #  Within sip URLs, the characters "?", "=", "&" are reserved.

    # hname      =  *urlc
    # hvalue     =  *urlc
    # header     =  hname "=" hvalue
    HEADER_PATTERN = "(?:[^?=&]*=[^?=&]*)".freeze
    HEADER_REGEXP  = Regexp.new(HEADER_PATTERN).freeze
    # port       = ":" *digit
    # pname      =  *urlc
    # pvalue     =  *urlc
    # parameter  =  pname "=" pvalue
    PARAMETER_PATTERN = "(?:[^?=&]*=[^?=&]*)".freeze
    PARAMETER_REGEXP  = Regexp.new(PARAMETER_PATTERN).freeze
    # parameters = ";" parameter *( ";" parameter )
    # headers    =  "?" header *( "&" header )
    # sipURL     =  "sip:" user "@" host [ port ] [ parameters ] [ headers ]
    SIP_REGEXP = Regexp.new(" # :nodoc:
      \\A
      (?:(#{PATTERN::USERINFO})\\@)?  (?# 1: user)
      (#{PATTERN::HOSTNAME})                          (?# 2: host)
      
      (:\\d*)?                          (?# 3: port)
      (?:
        \\;
        (#{PARAMETER_PATTERN}(?:\\;#{PARAMETER_PATTERN})*)  (?# 4: parameters)
      )?
      (?:
        \\?
        (#{HEADER_PATTERN}(?:\\&#{HEADER_PATTERN})*)  (?# 5: headers)
      )?
      \\z
    ", Regexp::EXTENDED).freeze
    # :startdoc:

    #
    # == Description
    #
    # Creates a new URI::SIP object from components, with syntax checking.
    #
    # Components can be provided as an Array or Hash. If an Array is used,
    # the components must be supplied as [to, headers].
    #
    # If a Hash is used, the keys are the component names preceded by colons.
    #
    # The headers can be supplied as a pre-encoded string, such as
    # "subject=subscribe&cc=address", or as an Array of Arrays like
    # [['subject', 'subscribe'], ['to', 'bob@example.com']]
    #
    # Examples:
    #
    #    require 'uri'
    #
    #    s1 = URI::SIP.build(['joe@example.com', 'user=phone'])
    #    puts s1.to_s  ->  sip:joe@example.com;subject=Ruby
    #
    #    s2 = URI::SIP.build(['john@example.com', [['user', 'phone'], ['method', 'REGISTER']]])
    #    puts s2.to_s  ->  sip:john@example.com;user=phone;method=REGISTER
    #
    #    s3 = URI::SIP.build({:to => 'alice@example.com', :headers => [['to', 'bob@example.com']]})
    #    puts s3.to_s  ->  sip:alice@example.com?to=bob%40example.com
    #
    def self.build(args)
      tmp = Util::make_components_hash(self, args)

      if tmp[:to]
        tmp[:opaque] = tmp[:to]
      else
        tmp[:opaque] = ''
      end

      if tmp[:headers]
        tmp[:opaque] << '?'

        if tmp[:headers].kind_of?(Array)
          tmp[:opaque] << tmp[:headers].collect { |x|
            if x.kind_of?(Array)
              x[0] + '=' + x[1..-1].join
            else
              x.to_s
            end
          }.join('&')

        elsif tmp[:headers].kind_of?(Hash)
          tmp[:opaque] << tmp[:headers].collect { |h,v|
            h + '=' + v
          }.join('&')

        else
          tmp[:opaque] << tmp[:headers].to_s
        end
      end

      return super(tmp)
    end

    #
    # == Description
    #
    # Creates a new URI::SIP object from generic URL components with
    # no syntax checking.
    #
    # This method is usually called from URI::parse, which checks
    # the validity of each component.
    #
    def initialize(*arg)
      super(*arg)

      @headers = []
      p @opaque

      if SIP_REGEXP =~ @opaque
        if arg[-1]
          self.user       = $1
          self.host       = $2
          self.port       = $3
          self.parameters = $4
          self.headers    = $5
        else
          raise "Unimplemented"
          set_to($1)
          set_headers($2)
        end

      else
        raise InvalidComponentError,
          "unrecognised opaque part for SIP URL: #{@opaque}"
      end
    end

    # The primary e-mail address of the URL, as a String
    attr_reader :to

    # E-mail headers set by the URL, as an Array of Arrays
    attr_reader :headers

    # check the to +v+ component against either
    # * URI::Parser Regexp for :OPAQUE
    # * MAILBOX_PATTERN
    def check_to(v)
      return true unless v
      return true if v.size == 0

      if parser.regexp[:OPAQUE] !~ v || /\A#{MAILBOX_PATTERN}*\z/o !~ v
        raise InvalidComponentError,
          "bad component(expected opaque component): #{v}"
      end

      return true
    end
    private :check_to

    # private setter for to +v+
    def set_to(v)
      @to = v
    end
    protected :set_to

    # setter for to +v+
    def to=(v)
      check_to(v)
      set_to(v)
      v
    end

    # check the headers +v+ component against either
    # * URI::Parser Regexp for :OPAQUE
    # * HEADER_PATTERN
    def check_headers(v)
      return true unless v
      return true if v.size == 0

      if parser.regexp[:OPAQUE] !~ v ||
          /\A(#{HEADER_PATTERN}(?:\&#{HEADER_PATTERN})*)\z/o !~ v
        raise InvalidComponentError,
          "bad component(expected opaque component): #{v}"
      end

      return true
    end
    private :check_headers

    # private setter for headers +v+
    def set_headers(v)
      @headers = []
      if v
        v.scan(HEADER_REGEXP) do |x|
          @headers << x.split(/=/o, 2)
        end
      end
    end
    protected :set_headers

    # setter for headers +v+
    def headers=(v)
      check_headers(v)
      set_headers(v)
      v
    end

    # Constructs String from URI
    def to_s
      @scheme + ':' +
        if @to
          @to
        else
          ''
        end +
        if @headers.size > 0
          '?' + @headers.collect{|x| x.join('=')}.join('&')
        else
          ''
        end +
        if @fragment
          '#' + @fragment
        else
          ''
        end
    end

    # Returns the RFC822 e-mail text equivalent of the URL, as a String.
    #
    # Example:
    #
    #   require 'uri'
    #
    #   uri = URI.parse("mailto:ruby-list@ruby-lang.org?Subject=subscribe&cc=myaddr")
    #   uri.to_mailtext
    #   # => "To: ruby-list@ruby-lang.org\nSubject: subscribe\nCc: myaddr\n\n\n"
    #
    def to_mailtext
      to = parser.unescape(@to)
      head = ''
      body = ''
      @headers.each do |x|
        case x[0]
        when 'body'
          body = parser.unescape(x[1])
        when 'to'
          to << ', ' + parser.unescape(x[1])
        else
          head << parser.unescape(x[0]).capitalize + ': ' +
            parser.unescape(x[1])  + "\n"
        end
      end

      return "To: #{to}
#{head}
#{body}
"
    end
    alias to_rfc822text to_mailtext
  end

  @@schemes['SIP'] = SIP
end
