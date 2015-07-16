module SimplyStored
  module Couch
    module Finders
      include PaginationOptions
      def find(*args)
        what = args.shift
        options = args.last.is_a?(Hash) ? args.last : {}
        if options && order = options.delete(:order)
          options[:descending] = true if order == :desc
        end

        with_deleted = options.delete(:with_deleted)

        result = case what
        when :all
          if options.has_key?(:page)
            options[:total_entries] = count
          end
          if with_deleted || !soft_deleting_enabled?
            with_pagination_options(options) do |options|
              database.view(all_documents(options))
            end
          else
            with_pagination_options(options) do |options|
              database.view(all_documents_without_deleted(options.update(:include_docs => true)))
            end
          end
        when :first
          if with_deleted || !soft_deleting_enabled?
            database.view(all_documents(options.update(:limit => 1, :include_docs => true))).first
          else
            database.view(all_documents_without_deleted(options.update(:limit => 1, :include_docs => true))).first
          end
        else
          raise SimplyStored::Error, "Can't load record without an id" if what.nil?
          document = database.load_document(what)
          if what.is_a?(Array) # Support for multiple find
            #TODO: extended validation and checking, for array arguments
          else
            if document.nil? or !document.is_a?(self) or (document.deleted? && !with_deleted)
              raise(SimplyStored::RecordNotFound, "#{self.name} could not be found with #{what.inspect}")
            end
          end
          document
        end
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
          database.view(all_documents(:reduce => true))
        else
          database.view(all_documents_without_deleted(:reduce => true))
        end
      end
    end
  end
end
