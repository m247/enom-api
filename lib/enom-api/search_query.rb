module EnomAPI
  class SearchQuery
    def initialize
      @options = {'responsetype' => 'xml', 'command' => 'advanceddomainsearch'}
    end
    def order_by(opt)
      raise ArgumentError, "invalid order by value" unless %w(sld tld nsstatus expdate renew).include?(opt)
      @options['orderby'] = opt
      self
    end
    def limit(num_or_start, num = nil)
      if num.nil?
        raise ArgumentError, "invalid limit" unless num_or_start.kind_of?(Integer)
        @options['recordstoreturn'] = num_or_start
      else
        raise ArgumentError, "invalid limit start" unless num_or_start.kind_of?(Integer)
        raise ArgumentError, "invalid limit size" unless num_or_start.kind_of?(Integer)
        @options['recordstoreturn'] = num
        @options['startposition'] = num_or_start
      end
      self
    end
    def where(conditions = {})
      @options = conditions.merge(@options)
      self
    end
    def to_post_data
      if @options[:creationdate].respond_to?(:strftime)
        @options[:creationdate] = @options[:creationdate].strftime("%m/%d/%Y")
      end
      @options
    end
  end
end
