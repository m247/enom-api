module EnomAPI
  class Client
    def initialize(user, passwd, mode = :live)
      @user, @mode = user, mode
      @conn = Interface.new(user, passwd, mode)
    end
    def inspect
      "#<#{self.class} #{@user}@#{@mode}>"
    end
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

    def check(*names)
      raise ArgumentError, "maximum number of names is 30" if names.size > 30
      xml = send_recv(:Check, :DomainNames => names.join(','))

      info = (0..xml.DomainCount.to_i).map do |i|
        [xml.send("Domain#{i}"), xml.send("RRPCode#{i}") == '210']
      end.flatten

      return info[1] if info.size == 2
      Hash[*info]
    end

    def check_ns_status(name)
      xml = send_recv(:CheckNSStatus, :CheckNSName => name)

      return false if xml.RRPCode != '200'
      { :name => xml.name, :ipaddress => xml.ipaddress }
    end

    def delete_nameserver(name)
      xml = send_recv(:DeleteNameServer, :NS => name)
      return xml.RRPCode == '200' && xml.NsSuccess == '1'
    end

    def renew(domain, period = '2y')
      xml = send_recv(:Extend, split_domain(domain).merge(:NumYears => period.to_i))

      return false if xml.RRPCode != '200'
      xml.OrderID
    end

    def get_dns(domain)
      xml = send_recv(:GetDNS, split_domain(domain))
      return false if xml.RRPCode != '200'

      nameservers = []
      xml.dns { nameservers << xml.strip }
      nameservers
    end

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

    def get_domain_exp(domain)
      xml = send_recv(:GetDomainExp, split_domain(domain))
      Time.parse(xml.ExpirationDate.strip)
    end

    def get_domain_info(domain)
      xml = send_recv(:GetDomainInfo, split_domain(domain))

      nameservers = []
      xml.services.entry do
        next unless xml['name'] == 'dnsserver'
        xml.configuration.dns do
          nameservers << xml.strip
        end
      end

      { :expires => Time.parse(xml.status.expiration.strip),
        :status => xml.status.registrationstatus.strip,
        :nameservers => nameservers }
    end

    def get_domain_status(domain, order_id = nil, order_type = :purchase)
      order_opts = order_id.nil? ? {} : { :OrderID => order_id, :OrderType => order_type }
      xml = send_recv(:GetDomainStatus, split_domain(domain).merge(order_opts))

      { :orderid => xml.OrderID,
        :in_account => xml.InAccount.to_i,
        :description => xml.StatusDesc }
    end

    def get_expired_domains
      xml = send_recv(:GetExpiredDomains)

      domains = {:expired => [], :extended_rgp => [], :rgp => []}
      xml.DomainDetail do
        case xml.status
        when /Expired/i
          domains[:expired]
        when /Extended RGP/i
          domains[:extended_rgp]
        when /RGP/i
          domains[:rgp]
        end << {
          :name => xml.DomainName,
          :id => xml.DomainNameID,
          :date => Time.parse(xml.send('expiration-date')),
          :locked => xml.lockstatus =~ /Locked/i
        }
      end
      domains
    end

    def get_extend_info(domain)
      xml = send_recv(:GetExtendInfo, split_domain(domain))

      { :expiration => Time.parse(xml.Expiration),
        :max_extension => xml.MaxExtension.to_i,
        :min_extension => xml.MinAllowed.to_i,
        :registrar_hold => xml.RegistrarHold? }
    end

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

    def push_domain(domain, account_id, push_contact = 1)
      xml = send_recv(:PushDomain, split_domain(domain).merge(
        :AccountID => account_id, :PushContact => push_contact))
      xml.PushDomain?
    end

    def register_nameserver(nameserver, ip)
      send_recv(:RegisterNameServer, :Add => 'true', :NSName => nameserver, :IP => ip)
      true  # send_recv will raise a ResponseError if ErrCount > 0
    end

    def set_reg_lock(domain, new_state) # true to lock, false to unlock
      xml = send_recv(:SetRegLock, split_domain(domain).merge(:UnlockRegistrar => (new_state ? '0' : '1')))

      ret = xml.RegistrarLock.strip
      return false if ret == 'Failed'
      ret
    end

    def update_expired_domains(domain, years) # Like :extend, but for expired domains
      xml = send_recv(:UpdateExpiredDomains, :DomainName => domain, :NumYears => years)
      xml.Status.strip
    end

    def update_nameserver(nameserver, old_ip, new_ip)
      xml = send_recv(:RegisterNameServer, :NS => nameserver, :OldIP => old_ip, :NewIP => new_ip)
      xml.NSSuccess?
    end

    def get_reg_lock(domain)
      xml = send_recv(:GetRegLock, split_domain(domain))
      xml.RegLock?
    end

    def get_registration_status(domain)
      xml = send_recv(:GetRegistrationStatus, split_domain(domain))
      { :hold => xml.RegistrarHold?, :status => xml.RegistrationStatus }
    end

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

    def get_order_detail(order_id)
      xml = send_recv(:GetOrderDetail, :OrderID => order_id)

      info = {}
      xml.Order do
        info[:result] = xml.Result?
        info[:details] = []

        xml.OrderDetail do
          info[:details] << {
            :product_type => xml.ProductType,
            :description => xml.Description,
            :status => xml.Status,
            :quantity => xml.Quantity.to_i 
          }
        end
      end
    end

    def get_ext_attributes(tld)
      xml = send_recv(:GetExtAttributes, :TLD => tld)

      attrs = []
      xml.Attributes do
        xml.Attribute do
          h = {
            :id => xml.ID,
            :name => xml.Name,
            :value => xml.Value,
            :title => xml.Title,
            :application => xml.Application == '2',
            :user_defined => xml.UserDefined,
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
    end

    def delete_registration(domain)
      xml = send_recv(:DeleteRegistration, split_domain(domain).merge(:EndUserIP => "127.000.000.001"))

      return true if xml.DomainDeleted?

      { :string => xml.ErrString,
        :source => xml.ErrSource,
        :section => xml.ErrSection }
    end

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

    def purchase(domain, registrant, nameservers, options = {})
      raise "Maximum nameserver limit is 12" if nameservers.size > 12
      opts = registrant.to_post_date('Registrant')
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
      def split_domain(domain)
        s, t = domain.split('.', 2)
        {:SLD => s, :TLD => t}
      end
      def send_recv(method, post_data = {}, &block)
        yield post_data if block
        response = @conn.send(method, post_data)
        xml = XML::Parser.string(response).parse

        if (err_count = xml.find('//ErrCount').first.content.strip.to_i) > 0
          errs = (1..err_count).map { |i| xml.find("//Err#{i}").first.content.strip }
          raise ResponseError.new(errs)
        end

        unless xml.find('//Done').first.content.strip =~ /true/i
          raise IncompleteResponseError.new(xml)
        end

        demolisher = Demolisher.demolish(xml)
        demolisher.send("interface-response")
      end
  end
end
