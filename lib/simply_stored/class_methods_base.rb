module SimplyStored
  module ClassMethods
    module Base
      def get_class_from_name(klass_name)
        klass_name.to_s.gsub('__','/').classify.constantize
      end
      
      def foreign_key
        name.underscore.gsub('/','__').gsub('::','__') + "_id"
      end
      
      def foreign_property
        name.underscore.gsub('/','__').gsub('::','__')
      end
      
      def attr_protected(*args)
        @_protected_attributes ||= []
        @_protected_attributes += args.to_a
      end
      
      def attr_accessible(*args)
        @_accessible_attributes ||= []
        @_accessible_attributes += args.to_a
      end
      
      def _find_property(name)
        properties.find{|property| property.name == name}
      end
        
      # Namespace aware method of creating proper class names    
      def find_association_class_name(association_name)
        (name.split('::')[0..-2] + [association_name.to_s.singularize.camelize]).join('::')
      end

      # Get documents by ids and bulk update attributes
      def bulk_update(ids, pairs)
        # Bulk load documents
        # Map to doc
        # Filter out errors, or none founds (compact)
        # Select the Couch objects
        docs = database.couchrest_database.bulk_load(ids)['rows'].map{|r| r['doc']}.compact.select{|d| d.is_a?(SimplyStored::Couch)}
        for doc in docs
          pairs.each_pair do |k, v|
            doc.send("#{k}=", v) if doc.respond_to?("#{k}=")
          end
          doc.save # Should become a bulk update in the future
        end
      end
    end
  end
end
