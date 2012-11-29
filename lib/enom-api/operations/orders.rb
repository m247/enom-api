module EnomAPI
  module Operations
    module Orders
      # Get detailed information about an order
      #
      # The returned hash contains the following keys
      # - (Boolean) +:result+ --        Order exists
      # - (Float) +:amount+ --          Billed amount
      # - (Array) +:details+ --         Details
      # - (String) +:status+ --         Order Status
      #
      # The +:details+ result key array contains hashes with the following keys
      # - (String) +:product_type+ --   Order detail item type
      # - (String) +:description+ --    Description of the detail
      # - (String) +:status+ --         Status of the order detail
      # - (Integer) +:quantity+ --      Number of the details of this type
      # - (Float) +:amount+ --          Amount paid for detail
      #
      # @param [String] order_id ID of the order
      # @return [Hash] order information
      def get_order_detail(order_id)
        xml = send_recv(:GetOrderDetail, :OrderID => order_id)

        info = {}
        xml.Order do
          info[:result] = xml.Result?
          info[:amount] = xml.OrderBillAmount
          info[:status] = xml.OrderStatus       # If this doesn't exist, then its under OrderDetail
          info[:details] = []

          xml.OrderDetail do
            info[:details] << {
              :product_type => xml.ProductType,
              :description => xml.Description,
              :status => xml.Status,
              :quantity => xml.Quantity.to_i,
              :amount => xml.AmountPaid,
              :order_status => xml.OrderStatus
            }
          end
        end
        info
      end

      # Get list of the account orders
      #
      # The returned array contains hashes with the following keys
      # - (String) +:id+ -- Order ID number
      # - (Time) +:date+ -- Date the order was placed
      # - (String) +:status+ -- Status of the order
      # - (BOOL) +:processed+ -- Whether the order has been processed
      #
      # @param [Hash] options Options to get the order list with
      # @option options [Integer] :start Starting offset in order list
      # @option options [String, #strftime] :begin String date or Date of earliest order to retrieve.
      #   If omitted then 6 months of orders are retrieved
      # @option options [String, #strftime] :end String date or Date or lastest order to retrieve.
      #   If omitted then the end is today
      # @return [Array] orders of :id, :date, :status and :processed
      def get_order_list(options = {})
        xml = send_recv(:GetOrderList, :Start => (options[:start] || 1)) do |h|
          h[:BeginDate] = if options[:begin].respond_to?(:strftime)
            options[:begin].strftime("%m/%d/%Y")
          else
            options[:begin]
          end

          h[:EndDate] = if options[:end].respond_to?(:strftime)
            options[:end].strftime("%m/%d/%Y")
          else
            options[:end]
          end
        end

        out = []
        xml.OrderList do
          xml.OrderDetail do
            { :id => xml.OrderID,
              :date => Time.parse(xml.OrderDate),
              :status => xml.StatusDesc,
              :processed => xml.OrderProcessFlag? }
          end
        end
        out
      end
    end
  end
end
