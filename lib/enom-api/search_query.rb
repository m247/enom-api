module EnomAPI
  # Class to define the parameters of an eNom search query
  class SearchQuery
    def initialize
      @options = {'responsetype' => 'xml', 'command' => 'advanceddomainsearch'}
    end

    # Change the ordering of the query results.
    #
    # @param [String] opt Ordering option, one of sld, tld, nsstatus, expdate, or renew
    def order_by(opt)
      raise ArgumentError, "invalid order by value" unless %w(sld tld nsstatus expdate renew).include?(opt)
      @options['orderby'] = opt
      self
    end

    # Limit the quantity of results returned
    #
    # @overload limit(number)
    #   @param [Integer] number Number of records to return
    # @overload limit(start, number)
    #   @param [Integer] start Start position in the results
    #   @param [Integer] number Number of records to return
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

    # @param [Hash] conditions Search conditions
    def where(conditions = {})
      @options = conditions.merge(@options)
      self
    end

    # @return POST data options
    def to_post_data
      if @options[:creationdate].respond_to?(:strftime)
        @options[:creationdate] = @options[:creationdate].strftime("%m/%d/%Y")
      end
      @options
    end
  end
end
