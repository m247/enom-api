require 'net/https'

module EnomAPI
  # Interface proxy for the eNom Reseller API
  class Interface

    # URL of the live eNom Reseller API
    LIVE_SERVER = 'https://reseller.enom.com/interface.asp'

    # URL of the test eNom Reseller API
    TEST_SERVER = 'https://resellertest.enom.com/interface.asp'

    # Version of the Interface class, sent with the HTTP requests
    VERSION = '0.0.1'

    # @param [String] user eNom Account Login ID
    # @param [String] passwd eNom Account Password
    # @param [Symbol] mode Interface type, `:live` or `:test`
    def initialize(user, passwd, mode = :live)
      @user, @passwd = user, passwd
      @uri = mode == :live ? URI.parse(LIVE_SERVER) : URI.parse(TEST_SERVER)
    end

    # @yield [q] Search query block
    # @yieldparam [SearchQuery] q SearchQuery instance
    # @return [String] XML Body of the Search Query results
    def search
      q = yield SearchQuery.new
      send_request(q.to_post_data)
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
            @request.add_field('User-Agent', "Ruby Enom API Client v#{VERSION}")
            @request.content_type = 'application/x-www-form-urlencoded'

            @request.body = data.merge(:uid => @user, :pw => @passwd).map { |k,v|
              "#{@request.send(:urlencode, k.to_s)}=#{@request.send(:urlencode, v.to_s)}" }.join("&")

            https.request(@request)
          end

          if @response.kind_of?(Net::HTTPSuccess)
            @response.body
          else
            raise @response
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
