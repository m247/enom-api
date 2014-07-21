module EnomAPI
  module Operations
    module Lock
      # Get the registrar lock setting for a domain
      #
      # @param [String] domain Domain name to check registrar lock of
      # @return [Boolean] locked state, true = locked
      def get_reg_lock(domain)
        xml = send_recv(:GetRegLock, split_domain(domain))
        xml.reg_lock.strip == "1"
      end

      # Sets the registrar lock on a domain name.
      #
      # @param [String] domain Domain to set the lock on
      # @param [Boolean] new_state True to lock, False to unlock
      # @return [false] if setting failed
      # @return [String] lock status
      def set_reg_lock(domain, new_state) # true to lock, false to unlock
        begin
          xml = send_recv(:SetRegLock, split_domain(domain).merge(:UnlockRegistrar => (new_state ? '0' : '1')))

          ret = xml.reg_lock.strip
          return false if ret == 'Failed'
          ret
        rescue ResponseError => e
          if e.message =~ /domain is already unlocked/
            return true
          end
          
          raise
        end
      end
    end
  end
end
