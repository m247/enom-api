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
    end
  end
end
