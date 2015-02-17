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

      # Get the list of TLDs available for the account and their info.
      #
      # Returns, for each TLD, a hash of the protocol used for the TLD
      # along with boolean values for the following keys
      #
      # - (Boolean) +:lockable+ -- If domains on this TLD can be locked
      # - (Boolean) +:realtime+ -- If domains on this TLD are handled in real time
      # - (Boolean) +:transferable+ -- If domains on this TLD are transferable
      # - (Boolean) +:auth_info+ -- If domains on this TLD have AUTH INFO
      # - (Boolean) +:transfer_auto+ -- If domains on this TLD support auto verification on transfers
      # - (Boolean) +:transfer_fax+ -- If domains on this TLD support fax verification on transfers
      #
      # @return [Hash<String,Hash>] array of TLDs available to the account
      def get_tld_info
        xml = send_recv(:TP_GetTLDInfo)

        tlds = {}

        xml.tldtable do
          xml.tld do
            tlds[xml.TLD.to_s] = {
              :protocol      => xml.Protocol.to_s,
              :lockable      => xml.AbleToLock?,
              :realtime      => xml.RealTime?,
              :transferable  => xml.Transferable?,
              :auth_info     => xml.HasAuthInfo?,
              :transfer_auto => xml.TransByAutoVeri?,
              :transfer_fax  => xml.TransByFax?
            }
          end
        end

        tlds
      end

      def get_domain_pricing(options = {})
        params = { :UseQtyEngine => options[:quantities] ? 1 : 0 }
        params[:Years] = options[:years].to_i if options[:years].to_i > 0

        xml = send_recv(:PE_GetDomainPricing, params)

        results = {}
        xml.pricestructure do
          xml.product do
            key = xml.tld.to_s
            results[key] = {
              :register => xml.registerprice.to_s,
              :registerreg => xml.registerprice.to_s,
              :renew => xml.renewprice.to_s,
              :renewreseller => xml.resellerpricerenew.to_s,
              :transfer => xml.transferprice.to_s,
              :transferreseller => xml.resellerpricetran.to_s
            }
          end
        end
        results
      end

      # Get the current account balance.
      #
      # Returns a hash of the following keys +:balance+ and +:available+. Per the
      # eNom Support Center FAQ the Available Balance is the current amount
      # available for your immediate use for registrations, transfers, renewals
      # and any other purchases. Once orders have become successful the difference
      # will be reflected in the Account Balance.
      #
      # @return [Hash<Symbol,Float>]
      def get_balance
        xml = send_recv(:GetBalance)

        return {
          :balance   => xml.Balance.to_s.gsub(',', '').to_f,
          :available => xml.AvailableBalance.to_s.gsub(',', '').to_f,
        }
      end
    end
  end
end
