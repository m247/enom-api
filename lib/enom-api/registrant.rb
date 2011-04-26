require 'demolisher'

module EnomAPI
  # Represents a registrant or other type of Contact in the eNom API
  class Registrant
    # @param [Demolisher, String] xmldoc Demolisher or XML String of registrant information
    # @return [Registrant] Registrant composed from the information in the xmldoc
    def self.from_xml(xmldoc)
      @xml = xml = xmldoc.kind_of?(Demolisher::Node) ? xmldoc : Demolisher.demolish(xmldoc.to_s)
      r = new("", "")

      mapping = if xml.FName
        from_xml_mapping_one
      elsif xml.RegistrantFirstName
        from_xml_mapping_two('Registrant')
      elsif xml.AuxBillingFirstName
        from_xml_mapping_two('AuxBilling')
      elsif xml.TechFirstName
        from_xml_mapping_two('Tech')
      elsif xml.AdminFirstName
        from_xml_mapping_two('Admin')
      elsif xml.BillingFirstName
        from_xml_mapping_two('Billing')
      end

      mapping.each do |meth, el|
        case el
        when Array
          r.send(:"#{meth}=", el.map { |n| xml.send(n).to_s }.delete_if { |n| n.nil? || n == "" }.join("\n"))
        else
          r.send(:"#{meth}=", xml.send(el).to_s)
        end
      end

      r
    end

    attr_accessor :id, :firstname, :lastname, :phone, :phone_extension, :fax, :email,
      :organisation, :job_title, :address, :city, :state, :postal_code, :country

    # @param [String] first Registrant first name
    # @param [String] last Registrant last name
    # @yield block to configure the registrant, any method on Registrant may be called.
    def initialize(first, last, &blk)
      raise ArgumentError, "first and last may not be nil" unless first && last

      @firstname, @lastname = first, last
      instance_eval(&blk) if blk
    end

    # Converts the object into a form suitable for POSTing to the eNom API
    #
    # @param [String] prefix String to prepend to key names
    # @return [Hash] Hash of data for the registrant
    def to_post_data(prefix=nil)
      data = {
        "#{prefix}FirstName" => firstname,
        "#{prefix}LastName" => lastname,
        "#{prefix}City" => city,
        "#{prefix}StateProvince" => state,
        "#{prefix}PostalCode" => postal_code,
        "#{prefix}Country" => country,
        "#{prefix}EmailAddress" => email,
        "#{prefix}Phone" => phone,
        "#{prefix}Fax" => fax }
      data["#{prefix}Address1"], data["#{prefix}Address2"] = address && address.split("\n", 2)

      unless organisation.nil? || organisation == ''
        data["#{prefix}OrganizationName"] = organisation
        data["#{prefix}JobTitle"] = (job_title || "Domains Manager")
      end

      data.reject { |_,v| v.nil? || v == '' }
    end
    private
      def self.from_xml_mapping_one
        { :firstname => :FName, :lastname => :LName,
          :organisation => :Organization, :job_title => :JobTitle,
          :city => :City, :state => :StateProvince, :postal_code => :PostalCode, :country => :Country,
          :phone => :Phone, :phone_extension => :PhoneExt, :fax => :Fax, :email => :EmailAddress,
          :address => [:Address1, :Address2] }
      end
      def self.from_xml_mapping_two(p = nil)
        { :id => "#{p}PartyID",
          :firstname => "#{p}FirstName", :lastname => "#{p}LastName",
          :organisation => "#{p}OrganizationName", :job_title => "#{p}JobTitle",
          :city => "#{p}City", :state => "#{p}StateProvince", :postal_code => "#{p}PostalCode", :country => "#{p}Country",
          :phone => "#{p}Phone", :phone_extension => "#{p}PhoneExt", :fax => "#{p}Fax", :email => "#{p}EmailAddress",
          :address => ["#{p}Address1", "#{p}Address2"] }
      end
  end
end
