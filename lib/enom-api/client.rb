require 'time'
require 'date'
require 'demolisher'

require File.expand_path('../operations/account', __FILE__)
require File.expand_path('../operations/contacts', __FILE__)
require File.expand_path('../operations/information', __FILE__)
require File.expand_path('../operations/lock', __FILE__)
require File.expand_path('../operations/nameservers', __FILE__)
require File.expand_path('../operations/orders', __FILE__)
require File.expand_path('../operations/registration', __FILE__)
require File.expand_path('../operations/renewal', __FILE__)
require File.expand_path('../operations/transfers', __FILE__)

module EnomAPI
  # Client
  class Client
    # @param [String] user eNom Account ID
    # @param [String] passwd eNom Account Password
    # @param [String] server Server to connect to. Use 'resellertest.enom.com' for test.
    def initialize(user, passwd, server = 'reseller.enom.com')
      @user, @server = user, server
      @conn = Interface.new(user, passwd, server)
    end
    def inspect # :nodoc:
      "#<#{self.class} #{@user}@#{@server}>"
    end

    include Operations::Account
    include Operations::Contacts
    include Operations::Information
    include Operations::Lock
    include Operations::Nameservers
    include Operations::Orders
    include Operations::Registration
    include Operations::Renewal
    include Operations::Transfers

    # Perform a search.
    #
    # The returned array contains hashes with the following keys
    # - (String) +:id+ -- Domain ID within the eNom registry
    # - (String) +:name+ -- Domain name
    # - (BOOL) +:auto_renew+ -- Whether auto-renew is set on the domain
    # - (Time) +:expires+ -- Expiration date of the domain
    # - (String) +:status+ -- Registration status of the domain
    # - (Array) +:nameservers+ -- Nameserver names
    #
    # @yield [q] block to build up search query
    # @yieldparam [SearchQuery] q SearchQuery instance
    # @return [Array] Array of hashes of search results
    #   including domain ID, name, auto_renew status, expiration date
    #   status and nameservers
    def search(&block)
      response = @conn.search(&block)
      xml = XML::Parser.string(response).parse

      o = Hash.new
      d = Demolisher.demolish(xml)
      d.send("interface-response") do
        d.DomainSearch do
          o[:total_results] = d.TotalResults.to_s.to_i
          o[:start_position] = d.StartPosition.to_s.to_i
          o[:next_position]  = d.NextPosition.to_s.to_i

          d.Domains do
            o[:results] = Array.new
            d.Domain do
              o[:results] << {
                :id => d.DomainNameID,
                :name => "#{d.SLD}.#{d.TLD}",
                :auto_renew => d.AutoRenew?,
                :expires => Time.parse(d.ExpDate),
                :status => d.DomainRegistrationStatus,
                :nameservers => (d.NameServers && d.NameServers.to_s.split(",")) }
            end
          end
        end
      end
      o
    end

    # Checks status of domain names
    #
    # @param [Array<String>] *names Names of domains to check the status of.
    # @return [Boolean] when 1 name provided, whether the domain is available or not
    # @return [Hash<String, Boolean>] when multiple names provided, hash of names
    #   and whether the domain is available or not
    # @raise [ArgumentError] if more than 30 names are provided
    def check(*names)
      raise ArgumentError, "maximum number of names is 30" if names.size > 30
      xml = send_recv(:Check, :DomainList => names.join(','))

      info = (1..xml.DomainCount.to_i).map do |i|
        [xml.send("Domain#{i}"), xml.send("RRPCode#{i}") == '210']
      end.flatten

      return info[1] if info.size == 2
      Hash[*info]
    end

    private
      # Split the domain into Top level and Domain components
      #
      # @param [String] domain Domain name to split
      # @return [Hash] with :SLD and :TLD parts
      def split_domain(domain)
        s, t = domain.split('.', 2)
        {:SLD => s, :TLD => t}
      end

      # Sends the payload
      #
      # @param [String] method API command name
      # @param [Hash] post_data Hash of POST data
      # @yield [post_data] Block to append additional post data
      # @yieldparam [Hash] post_data Hash of POST data
      # @raise [ResponseError] if any errors are returned from the command
      # @raise [IncompleteResponseError] if the response does not indicate Done
      def send_recv(method, post_data = {}, &block)
        yield post_data if block
        @response = @conn.send(method, post_data)
        xml = Nokogiri::XML.parse(@response)

        if (err_count = xml.xpath('//ErrCount').first.content.strip.to_i) > 0
          errs = (1..err_count).map { |i| xml.xpath("//Err#{i}").first.content.strip }
          raise ResponseError.new(errs)
        end

        unless xml.xpath('//Done').first.content.strip =~ /true/i
          raise IncompleteResponseError.new(xml)
        end

        demolisher = Demolisher.demolish(xml)
        demolisher.send("interface-response")
      end
  end
end
