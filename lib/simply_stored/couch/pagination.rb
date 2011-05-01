module SimplyStored
  module Couch
    module Pagination
      def total_pages_method(setter = nil)
        @_total_pages_method = setter if setter
        @_total_pages_method || 'total_pages'
      end

      def current_page_method(setter = nil)
        @_current_page_method = setter if setter
        @_current_page_method || 'current_page'
      end

      def num_pages_method(setter = nil)
        @_num_pages_method = setter if setter
        @_num_pages_method || 'num_pages'
      end

      def per_page_method(setter = nil)
        @_per_page_method = setter if setter
        @_per_page_method || 'per_page'
      end
    end
  end
end
