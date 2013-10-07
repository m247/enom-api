module EnomAPI
  module Operations
    module Transfers
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

      # @param [String] domain Domain to synchronise AUTH-INFO of
      # @param [Hash] options
      # @option options [Boolean] :email_epp Whether to email the new code to the registrant
      # @return [Boolean] whether the sync was successful or not
      def synch_auth_info(domain, options = {})
        email_epp_option = options[:email_epp] || false
        email_epp_option = email_epp_option ? 'True' : 'False'

        begin
          xml = send_recv(:SynchAuthInfo, split_domain(domain).merge(
            :RunSynchAutoInfo => 'True', :EmailEPP => email_epp_option))

          if options[:email_epp]
            !(xml.EPPEmailMessage =~ /Email has been sent/i).nil?
          else
            return xml.InfoSynched?
          end
        rescue IncompleteResponseError
          return false
        end
      end

      def transfer_domain(domain, authcode, new_registant = nil)
        payload = split_domain(domain)
        payload = { :SLD1 => payload[:SLD], :TLD1 => payload[:TLD],
          :AuthInfo1 => authcode, :DomainCount => 1, :Lock => 1,
          :OrderType => 'Autoverification', :Renew => 0,
          :UseContacts => 1, :PreConfig => 0 }

        if new_registant
          payload[:UseContacts] = 0
          payload = payload.merge(new_registant.to_post_data('Registrant'))
        end

        xml = send_recv(:TP_CreateOrder, payload)
        return xml.transferorder.transferorderid.strip
      end

      def get_transfer_order(transferorderid)
        xml = send_recv(:TP_GetOrder, {:TransferOrderID => transferorderid})

        data = {}
        xml.transferorder do
          data = {
            :transferorderid => xml.transferorderid.to_i,
            :orderdate => Time.strptime(xml.orderdate.strip, "%m/%d/%Y %H:%M:%S %p"),
            :ordertypeid => xml.ordertypeid.to_i,
            :ordertypedesc => xml.ordertypedesc.to_s,
            :statusid => xml.statusid.to_i,
            :statusdesc => xml.statusdesc.to_s,
            :authamount => xml.authamount.to_f,
            :version => xml.version.to_i,
            :orders => []
          }

          xml.transferorderdetail do
            data[:orders] << {
              :transferorderdetailid => xml.transferorderdetailid.to_i,
              :sld => xml.sld.to_s,
              :tld => xml.tld.to_s,
              :statusid => xml.statusid.to_i,
              :statusdesc => xml.statusdesc.to_s,
              :price => xml.price.to_f,
              :usecontacts => xml.usecontacts?
            }
          end
        end
        data
      end
      def get_transfer_order_detail(transferorderdetailid)
        xml = send_recv(:TP_GetOrderDetail, {:TransferOrderDetailID => transferorderdetailid})

        data = {}
        xml.transferorderdetail do
          data = {
            :transferorderdetailid => xml.transferordedetailrid.to_i,
            :sld => xml.sld.to_s,
            :tld => xml.tld.to_s,
            :lock => xml.lock?,
            :renew => xml.renew?,
            :statusid => xml.statusid.to_i,
            :statusdesc => xml.statusdesc.to_s,
            :price => xml.price.to_f,
            :usecontacts => xml.usecontacts?,
            :contacts => {}
          }

          xml.contacts do
            [:registrant, :aux_billing, :billing, :admin, :tech].each do |key|
              data = case key
              when :registrant  then xml.Registrant
              when :aux_billing then xml.AuxBilling
              when :billing     then xml.Billing
              when :admin       then xml.Admin
              when :tech        then xml.Tech
              end

              next if data == 'None'

              data[:contacts][key] = Registrant.from_xml(data)
            end
          end
        end
        data
      end
    end
  end
end
