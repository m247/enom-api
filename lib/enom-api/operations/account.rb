module EnomAPI
  module Operations
    module Account
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

      # Get the list of TLDs available for the account
      #
      # @return [Array<String>] array of TLDs available to the account
      def get_tld_list
        xml = send_recv(:GetTLDList)

        tlds = []
        xml.tldlist.tld do |tld,_|
          tld.tld do
            tlds << tld.to_s unless tld.to_s == ''
          end
        end
        tlds
      end
    end
  end
end
