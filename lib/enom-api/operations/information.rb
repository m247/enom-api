module EnomAPI
  module Operations
    module Information
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
    end
  end
end
