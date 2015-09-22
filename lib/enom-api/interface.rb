require 'net/https'

module EnomAPI
  # Interface proxy for the eNom Reseller API
  class Interface
    # Version of the Interface class, sent with the HTTP requests
    VERSION = '0.1.0'

    @@user_agent = nil
    def self.user_agent
      @@user_agent ||= begin
        engine  = defined?(RUBY_ENGINE)  ? RUBY_ENGINE.capitalize : "Ruby"
        "EnomAPI::Client/#{EnomAPI::VERSION} (#{engine} #{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}/#{RUBY_PLATFORM})"
      end
    end

    # @param [String] user eNom Account Login ID
    # @param [String] passwd eNom Account Password
    # @param [String] server Server to connect to
    def initialize(user, passwd, server = 'reseller.enom.com')
      @user, @passwd = user, passwd
      @uri = URI.parse('https://%s/interface.asp' % server)
    end

    # @yield [q] Search query block
    # @yieldparam [SearchQuery] q SearchQuery instance
    # @return [String] XML Body of the Search Query results
    def search
      q = yield SearchQuery.new
      send_request(q.to_post_data)
    end

    def last_request
      @request
    end
    def last_response
      @response
    end

    # @param [Symbol] meth API command to execute
    # @param [Hash] options POST data to send to the API
    # @return [String] XML Body of the response
    def method_missing(meth, options = {})
      send_request(options.merge(:command => meth.to_s, :responseType => 'xml'))
    end

    private
      # @param [Hash] data POST data to send to interface.asp
      # @param [Integer] attempts Number of attempts to try, default 3
      # @return [String] XML Body of the response
      def send_request(data, attempts = 3)
        begin
          s_client = Net::HTTP.new(@uri.host, @uri.port)
          s_client.use_ssl = true
          s_client.verify_mode = OpenSSL::SSL::VERIFY_NONE

          @response = s_client.start do |https|
            @request = Net::HTTP::Post.new(@uri.path)
            @request['Accept'] = 'text/xml'
            @request['User-Agent'] = self.class.user_agent
            @request['Connection'] = 'close'

            @request.set_form_data data.merge(:uid => @user, :pw => @passwd)

            https.request(@request)
          end

          if @response.kind_of?(Net::HTTPSuccess)
            @response.body
          else
            fail Net::HTTPBadResponse, @response
          end
        rescue ::Timeout::Error => e
          if attempts == 1
            raise e
          else
            send_request(data, attempts - 1)
          end
        end
      end
  end
end
