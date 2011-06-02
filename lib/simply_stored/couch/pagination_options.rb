module SimplyStored
  module Couch
    module PaginationOptions
      def with_pagination_options(options, &block)
        # Allow for manual setting of total_entries
        # If none given, default fallback will be total_rows
        # This is not true for a paginated find_all_by construction
        total_entries = options.delete(:total_entries)
        # Add limit and skip to options if requested
        if ([:page, :per_page] & options.keys).any? # Pagination active
          page = [options.delete(:page).to_i, 1].max
          per_page = options.delete(:per_page).to_i # Can be string
          per_page = 22 unless per_page > 0 # Nill will be 0
          options[:limit] = per_page
          options[:skip] = (page - 1) * options[:limit]
        elsif options[:offset] && options[:limit] # Sql syntax support
          options[:skip] = options.delete(:offset)
          options.delete(:order)
          page = (options[:skip].to_i / options[:limit].to_i).floor.succ
          per_page = options[:limit]
        else
          page = 1
          per_page = 22
        end
        result = block.call(options)
        if result
          result.instance_eval <<-PAGINATION, __FILE__, __LINE__
            unless respond_to?(:total_rows)
              def total_rows
                1
              end
            end
            def total_entries
              #{total_entries || 'total_rows'}
            end
            def #{current_page_method}
              #{page}
            end
            def #{num_pages_method}
              return 1 if total_entries.zero?
              (total_entries.to_f / #{per_page}).ceil
            end
            def #{per_page_method}
              #{per_page}
            end
          PAGINATION
        end
        result
      end
    end
  end
end
