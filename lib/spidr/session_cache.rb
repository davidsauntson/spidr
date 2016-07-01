require 'spidr/has_proxy'
require 'spidr/spidr'

require 'net/http'
require 'openssl'

module Spidr
  #
  # Stores active HTTP Sessions organized by scheme, host-name and port.
  #
  class SessionCache

    include HasProxy

    # Open timeout.
    #
    # @return [Integer, nil]
    attr_accessor :open_timeout

    # SSL timeout.
    #
    # @return [Integer, nil]
    attr_accessor :ssl_timeout

    # Read timeout.
    #
    # @return [Integer, nil]
    attr_accessor :read_timeout

    # `Continue` timeout.
    #
    # @return [Integer, nil]
    attr_accessor :continue_timeout

    # `Keep-Alive` timeout.
    #
    # @return [Integer, nil]
    attr_accessor :keep_alive_timeout

    #
    # Creates a new session cache.
    #
    # @param [Hash] options
    #   Configuration options.
    #
    # @option [Hash] :proxy (Spidr.proxy)
    #   Proxy options.
    #
    # @option [Integer] :open_timeout (Spidr.open_timeout)
    #   Optional open timeout.
    #
    # @option [Integer] :ssl_timeout (Spidr.ssl_timeout)
    #   Optional ssl timeout.
    #
    # @option [Integer] :read_timeout (Spidr.read_timeout)
    #   Optional read timeout.
    #
    # @option [Integer] :continue_timeout (Spidr.continue_timeout)
    #   Optional `Continue` timeout.
    #
    # @option [Integer] :keep_alive_timeout (Spidr.keep_alive_timeout)
    #   Optional `Keep-Alive` timeout.
    #
    # @since 0.6.0
    #
    def initialize(options={})
      @proxy = options.fetch(:proxy,Spidr.proxy)

      @open_timeout       = options.fetch(:open_timeout,Spidr.open_timeout)
      @ssl_timeout        = options.fetch(:ssl_timeout,Spidr.ssl_timeout)
      @read_timeout       = options.fetch(:read_timeout,Spidr.read_timeout)
      @continue_timeout   = options.fetch(:continue_timeout,Spidr.continue_timeout)
      @keep_alive_timeout = options.fetch(:keep_alive_timeout,Spidr.keep_alive_timeout)

      @sessions = {}
    end

    #
    # Determines if there is an active HTTP session for a given URL.
    #
    # @param [URI::HTTP, String] url
    #   The URL that represents a session.
    #
    # @return [Boolean]
    #   Specifies whether there is an active HTTP session.
    #
    # @since 0.2.3
    #
    def active?(url)
      # normalize the url
      url = URI(url.to_s) unless url.kind_of?(URI)

      # session key
      key = key_for(url)

      return @sessions.has_key?(key)
    end

    #
    # Provides an active HTTP session for a given URL.
    #
    # @param [URI::HTTP, String] url
    #   The URL which will be requested later.
    #
    # @return [Net::HTTP]
    #   The active HTTP session object.
    #
    def [](url)
      # normalize the url
      url = URI(url.to_s) unless url.kind_of?(URI)

      # session key
      key = key_for(url)

      unless @sessions[key]
        session = Net::HTTP::Proxy(
          @proxy.host,
          @proxy.port,
          @proxy.user,
          @proxy.password
        ).new(url.host,url.port)

        session.open_timeout       = @open_timeout
        session.read_timeout       = @read_timeout
        session.continue_timeout   = @continue_timeout
        session.keep_alive_timeout = @keep_alive_timeout

        if url.scheme == 'https'
          session.use_ssl     = true
          session.verify_mode = OpenSSL::SSL::VERIFY_NONE
          session.ssl_timeout = @ssl_timeout
          session.start
        end

        @sessions[key] = session
      end

      return @sessions[key]
    end

    #
    # Destroys an HTTP session for the given scheme, host and port.
    #
    # @param [URI::HTTP, String] url
    #   The URL of the requested session.
    #
    # @return [nil]
    #
    # @since 0.2.2
    #
    def kill!(url)
      # normalize the url
      url = URI(url.to_s) unless url.kind_of?(URI)

      # session key
      key = key_for(url)

      if (sess = @sessions[key])
        begin 
          sess.finish
        rescue IOError
        end

        @sessions.delete(key)
      end
    end

    #
    # Clears the session cache.
    #
    # @return [SessionCache]
    #   The cleared session cache.
    #
    # @since 0.2.2
    #
    def clear
      @sessions.each_value do |session|
        begin
          session.finish
        rescue IOError
        end
      end

      @sessions.clear
      return self
    end

    private

    #
    # Creates a session key based on the URL.
    #
    # @param [URI::HTTP] url
    #   The given URL.
    #
    # @return [Array]
    #   The session key containing the scheme, host and port.
    #
    def key_for(url)
      [url.scheme, url.host, url.port]
    end

  end
end
