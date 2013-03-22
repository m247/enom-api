require 'xml'
require 'demolisher'

require 'enom-api/version'

module EnomAPI  # :nodoc:
  autoload :Client, File.dirname(__FILE__) + '/enom-api/client.rb'
  autoload :Interface, File.dirname(__FILE__) + '/enom-api/interface.rb'
  autoload :Registrant, File.dirname(__FILE__) + '/enom-api/registrant.rb'
  autoload :SearchQuery, File.dirname(__FILE__) + '/enom-api/search_query.rb'

  # API Response error exception
  class ResponseError < RuntimeError
    attr_reader :messages
    def initialize(error_messages)
      super(Array(error_messages).join(", "))
      @messages = error_messages
    end
  end
  # API Incomplete response error
  class IncompleteResponseError < RuntimeError
    attr_reader :xml
    def initialize(xml)
      @xml = xml
    end
  end
end
