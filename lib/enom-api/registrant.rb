module EnomAPI
  class Registrant
    def self.from_xml(xmldoc)
      xml = xmldoc.kind_of?(Demolisher) ? xmldoc : Demolisher.demolish(xmldoc)

      new(xml.FName, xml.LName) do
        organisation    = xml.Organization
        city            = xml.City
        state           = xml.StateProvince
        postal_code     = xml.PostalCode
        phone           = xml.Phone
        phone_extension = xml.PhoneExtension
        fax             = xml.Fax
        email           = xml.EmailAddress
        address         = [xml.Address1, xml.Address2].join("\n")
      end
    end

    attr_accessor :firstname, :lastname, :phone, :phone_extension, :fax, :email,
      :organisation, :job_title, :address, :city, :state, :postal_code, :country

    def initialize(first, last, &blk)
      @firstname, @lastname = first, last
      instance_eval(&blk) if blk
    end

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
