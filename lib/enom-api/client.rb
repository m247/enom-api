module EnomAPI
  class Client
    LIVE_SERVER = 'https://reseller.enom.com/interface.asp'
    TEST_SERVER = 'https://resellertest.enom.com/interface.asp'
    VERSION = '0.0.1'

    def initialize(user, passwd, mode = :live)
      @user, @passwd = user, passwd
      @uri = mode == :real ? URI.parse(LIVE_SERVER) : URI.parse(TEST_SERVER)
    end
    def search
      q = yield SearchQuery.new
      send_request(q.to_query)
    end
    def method_missing(meth, options = {}, &block)
      send_request(options.merge(:command => meth.to_s, :responseType => 'xml'))
    end
    private
      def send_request(data, attempts = 3)
        begin
          s_client = Net::HTTP.new(@uri.host, @uri.port)
          s_client.use_ssl = true

          @response = s_client.start do |https|
            @request = Net::HTTP::Post.new(@uri.path)
            @request.add_field('User-Agent', "Ruby Enom API Client v#{VERSION}")
            @request.content_type = 'application/x-www-form-urlencoded'

            @request.body = data.merge(:uid => @user, :pw => @passwd).map { |k,v|
              "#{@request.send(:urlencode, k.to_s)}=#{@request.send(:urlencode, v.to_s)}" }.join("&")

            https.request(@request)
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
