require 'xml'
require 'demolisher'

module EnomAPI
  autoload :Client, File.dirname(__FILE__) + '/enom-api/client.rb'
  autoload :Interface, File.dirname(__FILE__) + '/enom-api/interface.rb'
  autoload :Registrant, File.dirname(__FILE__) + '/enom-api/registrant.rb'
  autoload :SearchQuery, File.dirname(__FILE__) + '/enom-api/search_query.rb'
end
