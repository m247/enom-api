require 'demolisher'

module EnomAPI
  # Represents a registrant or other type of Contact in the eNom API
  class Registrant
    # @param [Demolisher, String] xmldoc Demolisher or XML String of registrant information
    # @return [Registrant] Registrant composed from the information in the xmldoc
    def self.from_xml(xmldoc)
      @xml = xml = xmldoc.kind_of?(Demolisher::Node) ? xmldoc : Demolisher.demolish(xmldoc.to_s)

      r = new(xml.FName, xml.LName)
      r.organisation    = xml.Organization
      r.city            = xml.City
      r.state           = xml.StateProvince
      r.postal_code     = xml.PostalCode
      r.phone           = xml.Phone
      r.phone_extension = xml.PhoneExt
      r.fax             = xml.Fax
      r.email           = xml.EmailAddress
      r.address         = [xml.Address1, xml.Address2].delete_if{|a| a.nil? || a.to_s == ""}.join("\n")
      r
    end

    attr_accessor :firstname, :lastname, :phone, :phone_extension, :fax, :email,
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
      data["#{prefix}Address1"], data["#{prefix}Address2"] = address.split("\n", 2)

      unless organisation.nil? || organisation == ''
        data["#{prefix}OrganizationName"] = organisation
        data["#{prefix}JobTitle"] = (job_title || "Domains Manager")
      end
      data
    end
  end
end
