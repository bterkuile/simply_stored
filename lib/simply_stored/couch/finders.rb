module SimplyStored
  module Couch
    module Finders
      def find(*args)
        what = args.shift
        options = args.last.is_a?(Hash) ? args.last : {}
        if options && order = options.delete(:order)
          options[:descending] = true if order == :desc
        end
        
        # Add limit and skip to options if requested
        if ([:page, :per_page] & options.keys).any? # Pagination active
          page = [options.delete(:page).to_i, 1].max
          per_page = options.delete(:per_page).to_i # Can be string
          per_page = 22 unless per_page > 0 # Nill will be 0
          options[:limit] = per_page
          options[:skip] = (page - 1) * options[:limit]
        else
          page = 1
          per_page = 22
        end
        
        with_deleted = options.delete(:with_deleted)
        
        result = case what
        when :all
          if with_deleted || !soft_deleting_enabled?
            CouchPotato.database.view(all_documents(*args))
          else
            CouchPotato.database.view(all_documents_without_deleted(options.update(:include_docs => true)))
          end
        when :first
          if with_deleted || !soft_deleting_enabled?
            CouchPotato.database.view(all_documents(options.update(:limit => 1, :include_docs => true))).first
          else
            CouchPotato.database.view(all_documents_without_deleted(options.update(:limit => 1, :include_docs => true))).first
          end
        else          
          raise SimplyStored::Error, "Can't load record without an id" if what.nil?
          document = CouchPotato.database.load_document(what)
          if document.nil? or !document.is_a?(self) or (document.deleted? && !with_deleted)
            raise(SimplyStored::RecordNotFound, "#{self.name} could not be found with #{what.inspect}")
          end
          document
        end
        if result
          result.instance_eval <<-PAGINATION, __FILE__, __LINE__
            unless respond_to?(:total_rows)
              def total_rows
                1
              end
            end
            def #{current_page_method}
              #{page}
            end
            def #{num_pages_method}
              return 1 if total_rows.zero?
              (total_rows.to_f / #{per_page}).ceil
            end
            def #{per_page_method}
              #{per_page}
            end
          PAGINATION
        end
        result
      end
      
      def all(*args)
        find(:all, *args)
      end
      
      def first(*args)
        find(:first, *args)
      end

      def last(*args)
        options = args.last.is_a?(Hash) ? args.last : {}
        find(:first, options.update(:order => :desc))
      end

      def count(options = {})
        options.assert_valid_keys(:with_deleted)
        with_deleted = options[:with_deleted]
        
        if with_deleted || !soft_deleting_enabled?
          CouchPotato.database.view(all_documents(:reduce => true))
        else
          CouchPotato.database.view(all_documents_without_deleted(:reduce => true))
        end
      end
    end
  end
end
