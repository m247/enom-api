require 'time'
require 'demolisher'

module EnomAPI
  class Client
    # @param [String] user eNom Account ID
    # @param [String] passwd eNom Account Password
    # @param [Symbol] mode Type of session, `:live` or `:test`
    def initialize(user, passwd, mode = :live)
      @user, @mode = user, mode
      @conn = Interface.new(user, passwd, mode)
    end
    def inspect
      "#<#{self.class} #{@user}@#{@mode}>"
    end

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

      o = Array.new
      d = Demolisher.demolish(xml)
      d.send("interface-response") do
        d.DomainSearch do
          d.Domains do
            d.Domain do
              o << {
                :id => d.DomainNameID,
                :name => "#{d.SLD}.#{d.TLD}",
                :auto_renew => d.AutoRenew?,
                :expires => Time.parse(d.ExpDate),
                :status => d.DomainRegistrationStatus,
                :nameservers => d.NameServers.split(",") }
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
      xml = send_recv(:Check, :DomainNames => names.join(','))

      info = (0..xml.DomainCount.to_i).map do |i|
        [xml.send("Domain#{i}"), xml.send("RRPCode#{i}") == '210']
      end.flatten

      return info[1] if info.size == 2
      Hash[*info]
    end

    # Checks the status of a nameserver registered with eNom.
    #
    # @param [String] name nameserver to check
    # @return [Hash] the nameserver +:name+ and +:ipaddress+
    # @return [false] the nameserver is not registered with eNom
    def check_ns_status(name)
      xml = send_recv(:CheckNSStatus, :CheckNSName => name)

      return false if xml.RRPCode != '200'
      { :name => xml.name, :ipaddress => xml.ipaddress }
    end

    # Delete a registered nameserver from eNom
    #
    # @param [String] name nameserver to delete from the registry
    # @return [Boolean] +true+ if deleted successfully, +false+ if not
    def delete_nameserver(name)
      xml = send_recv(:DeleteNameServer, :NS => name)
      return xml.RRPCode == '200' && xml.NsSuccess == '1'
    end

    # Deletes a domain registration.
    #
    # The domain registration must be less than 5 days old. eNom requires an +EndUserIP+
    # to be sent with the request, this is set to +127.0.0.1+.
    #
    # @param [String] domain Name of the registered domain
    # @return [true] if successfully deleted
    # @return [Hash] Error details with +:string+, +:source+ and +:section+ information
    def delete_registration(domain)
      xml = send_recv(:DeleteRegistration, split_domain(domain).merge(:EndUserIP => "127.000.000.001"))

      return true if xml.DomainDeleted?

      { :string => xml.ErrString,
        :source => xml.ErrSource,
        :section => xml.ErrSection }
    end

    # Gets the list of nameserver for a domain.
    #
    # @param [String] domain name of domain to collect nameservers of
    # @return [Array<String>] array of nameservers
    # @return [false] no nameservers for the domain
    def get_dns(domain)
      xml = send_recv(:GetDNS, split_domain(domain))
      return false if xml.RRPCode != '200'

      nameservers = []
      xml.dns { nameservers << xml.strip }
      nameservers
    end

    # Get the number of domains in the account in specific groups.
    #
    # The groups of domains and their result keys are:
    # - (Integer) +:registered+ -- Registered
    # - (Integer) +:hosted+ -- Hosted
    # - (Integer) +:expiring+ -- Expiring
    # - (Integer) +:expired+ -- Expired
    # - (Integer) +:redemption+ -- Redemption
    # - (Integer) +:extended_redemption+ -- Extended Redemption
    # - (Integer) +:processing+ -- Processing
    # - (Integer) +:watch_list+ -- Watch List
    #
    # @return [Hash] Hash of number of domains in each group
    def get_domain_count
      xml = send_recv(:GetDomainCount)

      { :registered =>          xml.RegisteredCount.to_i,
        :hosted =>              xml.HostCount.to_i,
        :expiring =>            xml.ExpiringCount.to_i,
        :expired =>             xml.ExpiredDomainsCount.to_i,
        :redemption =>          xml.RGP.to_i,
        :extended_redemption => xml.ExtendedRGP.to_i,
        :processing =>          xml.ProcessCount.to_i,
        :watch_list =>          xml.WatchlistCount.to_i }
    end

    # Get the expiration date of a domain
    #
    # @param [String] domain Domain name
    # @return [Time] expiration date of the domain
    def get_domain_exp(domain)
      xml = send_recv(:GetDomainExp, split_domain(domain))
      Time.parse(xml.ExpirationDate.strip)
    end

    # Get the domain information for a domain
    #
    # The information returned includes the following
    # - (Time) +:expires+ -- Expiration date
    # - (String) +:status+ -- Status
    # - (Array) +:nameservers+ -- Nameserver names
    #
    # @param [String] domain Domain name
    # @return [Hash] information for the domain
    def get_domain_info(domain)
      xml = send_recv(:GetDomainInfo, split_domain(domain))
      xml = xml.GetDomainInfo

      nameservers = []
      xml.services.entry do |entry,_|
        next unless entry['name'] == 'dnsserver'
        entry.configuration.dns do |dns,_|
          nameservers << dns.to_s
        end
      end

      { :expires => Time.parse(xml.status.expiration.strip),
        :status => xml.status.registrationstatus.strip,
        :nameservers => nameservers }
    end

    # Get the registration status of a domain. Used for TLDs which
    # do not register in real time.
    #
    # The hash returned includes the following information:
    # - (String) +:order_id+ -- Order ID
    # - (Integer) +:in_account+ -- In Account, one of 0, 1, 2
    # - (String) +:description+ -- Description of In Account
    # - (Time) +:expires+ -- Expiration Date
    #
    # The +:in_account+ field will have one of the following numeric values and meanings
    # - 0: Domain is not in the eNom database
    # - 1: Domain is in the eNom database and the recievers account
    # - 2: Domain is in the eNom database but not the receivers account
    #
    # The +:description+ field contains a textual representation of the +:in_account+
    # value, it will not necessarily match those given above. The meanings however
    # should be correct.
    #
    # @overload get_domain_status(domain)
    #   @param [String] domain Name of the domain to get status for
    # @overload get_domain_status(domain, order_id, order_type = :purchase)
    #   @param [String] domain Name of the domain to get status for
    #   @param [String] order_id Order ID to get information for
    #   @param [Symbol] order_type Type of order information to obtain, +:purchase+, +:transfer+, or +:extend+
    # @return [Hash] Hash of registration information
    def get_domain_status(domain, order_id = nil, order_type = :purchase)
      order_opts = order_id.nil? ? {} : { :OrderID => order_id, :OrderType => order_type }
      xml = send_recv(:GetDomainStatus, split_domain(domain).merge(order_opts))

      { :orderid => xml.OrderID,
        :in_account => xml.InAccount.to_i,
        :description => xml.StatusDesc,
        :expires => Time.parse(xml.ExpDate.strip) }
    end

    # Get a list of the domains in the Expired, Redemption and Extended Redemption groups.
    #
    # The returned hash has the following keys
    # - (Array) +:expired+ -- Expired domains
    # - (Array) +:redemption+ -- Domains in Redemption Grace Period (RGP)
    # - (Array) +:extended_redemption+ -- Domains in Extended RGP
    #
    # Each array contains hashes with the following keys
    # - (String) +:name+ -- The domain name
    # - (String) +:id+ -- The domains eNom registry ID
    # - (Time) +:date+ -- Expiration date of the domain
    # - (BOOL) +:locked+ -- Domain locked status
    #
    # @return [Hash] Hash of expired domains information
    def get_expired_domains
      xml = send_recv(:GetExpiredDomains)

      domains = {:expired => [], :extended_redemption => [], :redemption => []}
      xml.DomainDetail do
        case xml.status
        when /Expired/i
          domains[:expired]
        when /Extended RGP/i
          domains[:extended_redemption]
        when /RGP/i
          domains[:redemption]
        end << {
          :name => xml.DomainName,
          :id => xml.DomainNameID,
          :date => Time.parse(xml.send('expiration-date')),
          :locked => xml.lockstatus =~ /Locked/i
        }
      end
      domains
    end

    # @param [String] domain Domain name to renew
    # @param [String] period Number of years to extend the registration by
    # @return [String] Order ID of the renewal
    # @return [false] the order did not succeed
    def renew(domain, period = '2y')
      xml = send_recv(:Extend, split_domain(domain).merge(:NumYears => period.to_i))

      return false if xml.RRPCode != '200'
      xml.OrderID
    end
    alias :extend :renew

    # Get the list of extended attributes required by a TLD
    #
    # The returned array of extended attributes contains hashes of the attribute details.
    # The details include the following information
    # - (String) +:id+ --            eNom internal attribute ID
    # - (String) +:name+ --          Form parameter name
    # - (String) +:title+ --         Short definition of the parameter value
    # - (BOOL) +:application+ --     Attribute required for Registrant contact
    # - (BOOL) +:user_defined+ --    Attribute value must be provided by user
    # - (BOOL) +:required+ --        Attribute is required
    # - (String) +:description+ --   Long definition of the parameter value
    # - (String) +:is_child+ --      Is a child of another
    # - (Array) +:options+ --        Array of options for the attribute
    #
    # Attribute options include the following information
    # - (String) +:id+ --            eNom internal attribute option ID
    # - (String) +:value+ --         Value of the option
    # - (String) +:title+ --         Short definition of the parameter value
    # - (String) +:description+ --   Long definition of the parameter value
    #
    # @param [String] tld Top Level Domain
    # @return [Array] extended attributes, their details and valid options
    def get_ext_attributes(tld)
      xml = send_recv(:GetExtAttributes, :TLD => tld)

      attrs = []
      xml.Attributes do
        xml.Attribute do
          h = {
            :id => xml.ID,
            :name => xml.Name,
            :title => xml.Title,
            :application => xml.Application == '2',
            :user_defined => xml.UserDefined?,
            :required => xml.Required?,
            :description => xml.Description,
            :is_child => xml.IsChild?,
            :options => Array.new }
          attrs << h
          xml.Options do
            xml.Option do
              h[:options] << {
                :id => xml.ID,
                :value => xml.Value,
                :title => xml.Title,
                :description => xml.Description
              }
            end
          end
        end
      end
      attrs
    end

    # Get renewal information for a domain
    #
    # The returned hash contains the following keys
    # - (Time) +:expiration+ --       Time the domain expires
    # - (Integer) +:max_extension+ -- Maximum number of years which can be added
    # - (Integer) +:min_extension+ -- Minimum number of years which can be added
    # - (BOOL) +:registrar_hold+ --   Registrar hold state
    # - (Float) +:balance+ --         Current account balance
    # - (Float) +:available+ --       Available account balance
    #
    # @param [String] domain Domain name
    # @return [Hash] Renewal information
    def get_extend_info(domain)
      xml = send_recv(:GetExtendInfo, split_domain(domain))

      { :expiration => Time.parse(xml.Expiration),
        :max_extension => xml.MaxExtension.to_i,
        :min_extension => xml.MinAllowed.to_i,
        :registrar_hold => xml.RegistrarHold?,
        :balance => xml.Balance.to_f,
        :available => xml.AvailableBalance.to_f }
    end

    # Get detailed information about an order
    #
    # The returned hash contains the following keys
    # - (BOOL) +:result+ --           Order exists
    # - (Float) +:amount+ --          Billed amount
    # - (Array) +:details+ --         Details
    #
    # The +:details+ result key array contains hashes with the following keys
    # - (String) +:product_type+ --   Order detail item type
    # - (String) +:description+ --    Description of the detail
    # - (String) +:status+ --         Status of the order detail
    # - (Integer) +:quantity+ --      Number of the details of this type
    # - (Float) +:amount+ --          Amount paid for detail
    #
    # @param [String] order_id ID of the order
    # @return [Hash] order information
    def get_order_detail(order_id)
      xml = send_recv(:GetOrderDetail, :OrderID => order_id)

      info = {}
      xml.Order do
        info[:result] = xml.Result?
        info[:amount] = xml.OrderBillAmount
        info[:details] = []

        xml.OrderDetail do
          info[:details] << {
            :product_type => xml.ProductType,
            :description => xml.Description,
            :status => xml.Status,
            :quantity => xml.Quantity.to_i,
            :amount => xml.AmountPaid
          }
        end
      end
    end

    # Get list of the account orders
    #
    # The returned array contains hashes with the following keys
    # - (String) +:id+ -- Order ID number
    # - (Time) +:date+ -- Date the order was placed
    # - (String) +:status+ -- Status of the order
    # - (BOOL) +:processed+ -- Whether the order has been processed
    #
    # @param [Hash] options Options to get the order list with
    # @option options [Integer] :start Starting offset in order list
    # @option options [String, #strftime] :begin String date or Date of earliest order to retrieve.
    #   If omitted then 6 months of orders are retrieved
    # @option options [String, #strftime] :end String date or Date or lastest order to retrieve.
    #   If omitted then the end is today
    # @return [Array] orders of :id, :date, :status and :processed
    def get_order_list(options = {})
      xml = send_recv(:GetOrderList, :Start => (options[:start] || 1)) do |h|
        h[:BeginDate] = if options[:begin].respond_to?(:strftime)
          options[:begin].strftime("%m/%d/%Y")
        else
          options[:begin]
        end

        h[:EndDate] = if options[:end].respond_to?(:strftime)
          options[:end].strftime("%m/%d/%Y")
        else
          options[:end]
        end
      end

      out = []
      xml.OrderList do
        xml.OrderDetail do
          { :id => xml.OrderID,
            :date => Time.parse(xml.OrderDate),
            :status => xml.StatusDesc,
            :processed => xml.OrderProcessFlag? }
        end
      end
      out
    end

    # Get the registration status of a domain.
    #
    # The returned hash has the following keys
    # - (BOOL) +:hold+ --           Registrar hold set
    # - (String) +:registration+ -- Registration status of the domain
    # - (String) +:purchase+ --     Purchase status of the domain
    #
    # Registration status will be one of
    # 1. Processing
    # 2. Registered
    # 3. Hosted
    # 4. Null
    #
    # Purchase status will be one of
    # 1. Processing
    # 2. Paid
    # 3. Null
    #
    # @param [String] domain Domain name to get registration status of
    # @return [Hash] :hold and :status
    def get_registration_status(domain)
      xml = send_recv(:GetRegistrationStatus, split_domain(domain))
      { :hold => xml.RegistrarHold?, :registration => xml.RegistrationStatus, :purchase => xml.PurchaseStatus }
    end

    # Get the registrar lock setting for a domain
    #
    # @param [String] domain Domain name to check registrar lock of
    # @return [Boolean] locked state, true = locked
    def get_reg_lock(domain)
      xml = send_recv(:GetRegLock, split_domain(domain))
      xml.RegLock?
    end

    # Get the list of TLDs available for the account
    #
    # @return [Array<String>] array of TLDs available to the account
    def get_tld_list
      xml = send_recv(:GetTLDList)

      tlds = []
      xml.tldlist.tld do
        xml.tld do
          tlds << xml.strip unless xml.nil? || xml.strip == ''
        end
      end
      tlds
    end

    # Gets the WHOIS contact details for a domain
    #
    # The returned hash has the following keys
    # - (Registrant) +:registrant+ -- Registrant object
    # - (Time) +:updated_date+ --     Domain last update time
    # - (Time) +:created_date+ --     Domain creation date
    # - (Time) +:expiry_date+ --      Domain expiration date
    # - (Array) +:nameservers+ --     Array of name server names
    #
    # @param [String] domain Domain name to retrieve WHOIS information for
    # @return [Hash] response data
    def get_whois_contact(domain)
      xml = send_recv(:GetWhoisContact, split_domain(domain))

      out = { :registrant => Registrant.from_xml(xml._current_node.find('//contact[@ContactType="Registrant"]').first) }
      xml.send("rrp-info") do
        out[:updated_date] = Time.parse(xml.send("updated-date"))
        out[:created_date] = Time.parse(xml.send("created-date"))
        out[:expiry_date]  = Time.parse(xml.send("registration-expiration-date"))
        out[:nameservers]  = Array.new
        xml.nameserver do
          xml.nameserver do
            out[:nameservers] << xml.strip
          end
        end
      end
      out
    end

    # Push a domain to another eNom account.
    #
    # This is much like a domain transfer except it is wholly within the scope
    # of eNoms registration system.
    #
    # @param [String] domain Domain name to push
    # @param [String] account_id eNom Account ID to push the domain to
    # @param [Boolean] push_contact Should push the domain contact information
    # @return [Boolean] whether the push was successful or not
    def push_domain(domain, account_id, push_contact = true)
      xml = send_recv(:PushDomain, split_domain(domain).merge(
        :AccountID => account_id, :PushContact => (push_contact ? 1 : 0)))
      xml.PushDomain?
    end

    # Register a domain name server
    #
    # @param [String] nameserver Nameserver to register
    # @param [String] ip IPv4 Address of the nameserver
    # @return true if registration was successful
    # @raise [ResponseError] if an error occurred
    def register_nameserver(nameserver, ip)
      send_recv(:RegisterNameServer, :Add => 'true', :NSName => nameserver, :IP => ip)
      true  # send_recv will raise a ResponseError if ErrCount > 0
    end

    # Sets the registrar lock on a domain name.
    #
    # @param [String] domain Domain to set the lock on
    # @param [Boolean] new_state True to lock, False to unlock
    # @return [false] if setting failed
    # @return [String] lock status
    def set_reg_lock(domain, new_state) # true to lock, false to unlock
      xml = send_recv(:SetRegLock, split_domain(domain).merge(:UnlockRegistrar => (new_state ? '0' : '1')))

      ret = xml.RegistrarLock.strip
      return false if ret == 'Failed'
      ret
    end

    # Reactivates an expired domain in real time.
    #
    # @param [String] domain Expired Domain name to register
    # @param [Number] years Number of years to register the domain for
    # @return [String] response status
    def update_expired_domains(domain, years) # Like :extend, but for expired domains
      xml = send_recv(:UpdateExpiredDomains, :DomainName => domain, :NumYears => years)
      xml.Status.strip
    end

    # Change the IP address of a registered name server.
    #
    # @param [String] nameserver Nameserver to update the IP address of
    # @param [String] old_ip Old IPv4 address of the nameserver
    # @param [String] new_ip New IPv4 address of the nameserver
    # @return [Boolean] success or failure of the update
    def update_nameserver(nameserver, old_ip, new_ip)
      xml = send_recv(:RegisterNameServer, :NS => nameserver, :OldIP => old_ip, :NewIP => new_ip)
      xml.NSSuccess?
    end

    # Modify the name servers for a domain.
    #
    # @param [String] domain Domain name to set the nameserver of
    # @param [String, ...] nameservers Nameservers to set for the domain
    # @raise [RuntimeError] if number of nameservers exceeds 12
    def modify_ns(domain, *nameservers)
      raise "Maximum nameserver limit is 12" if nameservers.size > 12
      xml = send_recv(:ModifyNS, split_domain(domain)) do |d|
        if nameservers.empty?
          d['NS1'] = ''
        else
          nameservers.each_with_index do |n,i|
            d["NS#{i}"] = n
          end
        end
      end
      xml.RRPCode == '200'
    end

    # Gets information about a domain
    #
    # The returned hash contains the following keys
    # - (BOOL) +:known+ -- Whether the domain is known to eNom
    # - (BOOL) +:in_account+ -- Whether the domain belongs to the account
    # - (String) +:last_order_id+ -- Last Order ID for the domain if domain belongs to the account
    #
    # @param [String] domain Domain to check the status of
    # @param [String] type Order Type to query with, one of 'Purchase', 'Transfer' or 'Extend'
    # @return [Hash] of information about the domain
    def status_domain(domain, type = 'Purchase')
      raise ArgumentError, "type must be Purchase, Transfer or Extend" unless %w(purchase transfer extend).include?(type.downcase)
      begin
        xml = send_recv(:StatusDomain, split_domain(domain).merge(:OrderType => type))

        xml.DomainStatus do
          return { :known => (xml.Known == 'Known'),
            :in_account => xml.InAccount?,  # It'll be either 0 or 1 here, case 2 raises an exception
            :last_order_id => xml.OrderID }
        end
      rescue ResponseError => e
        if e.messages.include?("The domain does not belong to this account")
          # It returns an error if the domain is known to eNom but in another account
          return { :known => true, :in_account => false }
        end
      end
    end

    # Purchase a domain name.
    #
    # The returned hash has the following keys
    # - (Symbol) +:result+ --   Either +:registered+ or +:ordered+. The latter if the TLD does not support real time registrations.
    # - (String) +:order_id+ -- Order ID of the purchase
    #
    # @param [String] domain Domain name to register
    # @param [Registrant] registrant Registrant of the domain
    # @param [Array<String>, nil] nameservers Nameservers to set for the domain, nil sends blank NS1
    # @param [Hash] options Options to configure the registration
    # @option options [Integer] :period Number of years to register the domain for
    # @return [Hash] :result => :registered and :order_id if successful
    # @return [Hash] :result => :ordered and :order_id if not a Real Time TLD
    # @raise [RuntimeError] if more than 12 nameservers are passed
    # @raise [ResponseError] if regisration failed
    def purchase(domain, registrant, nameservers, options = {})
      raise "Maximum nameserver limit is 12" if nameservers.size > 12
      opts = registrant.to_post_data('Registrant')
      opts[:NumYears] = options.delete(:period) if options.has_key?(:period)

      xml = send_recv(:Purchase, split_domain(domain).merge(opts)) do |d|
        if nameservers.empty?
          d['NS1'] = ''
        else
          nameservers.each_with_index do |n,i|
            d["NS#{i}"] = n
          end
        end
      end

      case xml.RRPCode.to_i
      when 200
        return { :result => :registered, :order_id => xml.OrderID }
      when 1300
        raise ResponseError.new([xml.RRPText]) if xml.IsRealTimeTLD?
        return { :result => :ordered, :order_id => xml.OrderID }
      end
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
