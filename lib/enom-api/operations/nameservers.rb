module EnomAPI
  module Operations
    module Nameservers
      # Checks the status of a nameserver registered with eNom.
      #
      # @param [String] name nameserver to check
      # @return [Hash] the nameserver +:name+ and +:ipaddress+
      # @return [false] the nameserver is not registered with eNom
      def check_ns_status(name)
        xml = send_recv(:CheckNSStatus, :CheckNSName => name)

        return false if xml.RRPCode != '200'
        { :name => xml.CheckNsStatus.name, :ipaddress => xml.CheckNsStatus.ipaddress }
      end

      # Delete a registered nameserver from eNom
      #
      # @param [String] name nameserver to delete from the registry
      # @return [Boolean] +true+ if deleted successfully, +false+ if not
      def delete_nameserver(name)
        xml = send_recv(:DeleteNameServer, :NS => name)
        return xml.RRPCode == '200' && xml.NsSuccess == '1'
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

      # Change the IP address of a registered name server.
      #
      # @param [String] nameserver Nameserver to update the IP address of
      # @param [String] old_ip Old IPv4 address of the nameserver
      # @param [String] new_ip New IPv4 address of the nameserver
      # @return [Boolean] success or failure of the update
      def update_nameserver(nameserver, old_ip, new_ip)
        xml = send_recv(:UpdateNameServer, :NS => nameserver, :OldIP => old_ip, :NewIP => new_ip)
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
              d["NS#{i+1}"] = n
            end
          end
        end
        xml.RRPCode == '200'
      end
    end
  end
end
