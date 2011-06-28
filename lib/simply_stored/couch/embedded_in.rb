# Gracefully taken from CouchPotato after it has been removed for good.
module SimplyStored
  module Couch
    module EmbeddedIn
      include SimplyStored::Couch::Properties

      def is_embedded_in(name, options = {})
        check_existing_properties(name, SimplyStored::Couch::BelongsTo::Property)
        parent = options[:class_name] || name.to_s.camelize
        self.name.property_name.pluralize

        map_definition_without_deleted = <<-eos
          function(doc) { 
            if (doc['ruby_class'] == '#{parent}') {
              if(typeof(doc['']))
              if (doc['#{soft_delete_attribute}'] && doc['#{soft_delete_attribute}'] != null){
                // "soft" deleted
              }else{
                emit([doc.#{name.to_s}_id, doc.created_at], 1);
              }
            }
          }
        eos
        
        reduce_definition = "_sum"
         
        view "association_#{self.name.underscore.gsub('/', '__')}_embedded_in_#{name}",
          :map => map_definition_without_deleted,
          :reduce => reduce_definition,
          :type => "custom",
          :include_docs => true
          
        map_definition_with_deleted = <<-eos
          function(doc) { 
            if (doc['ruby_class'] == '#{self.to_s}' && doc['#{name.to_s}_id'] != null) {
              emit([doc.#{name.to_s}_id, doc.created_at], 1);
            }
          }
        eos
         
        view "association_#{self.name.underscore.gsub('/', '__')}_embedded_in_#{name}_with_deleted",
          :map => map_definition_with_deleted,
          :reduce => reduce_definition,
          :type => "custom",
          :include_docs => true
            
        properties << SimplyStored::Couch::EmbeddedIn::Property.new(self, name, options)
      end

      class Property #:nodoc:
        attr_accessor :name, :options
      
        def initialize(owner_clazz, name, options = {})
          @name = name
          @options = {
            :class_name => name.to_s.singularize.camelize
          }.update(options)

          @options.assert_valid_keys(:class_name)

          # For now restrictions on naming
          parent_property_name = owner_clazz.name.property_name.pluralize

          owner_clazz.class_eval do
            property :"#{name}_id"
            attr_accessor :parent_object
            
            view :all_documents, :type => :raw, :include_docs => true, :map => %{
              function(doc){
                if(doc['ruby_class'] == '#{name.to_s.singularize.camelize}' && typeof(doc['#{parent_property_name}']) == 'object'){
                  for(var i=0; i < doc['#{parent_property_name}'].length; i++){
                    emit(doc['#{parent_property_name}'][i]['created_at'], doc['#{parent_property_name}'][i]);
                  }
                }
              }
            }, :results_filter => lambda{|results| results['rows'].map{|row| d = row['value']; d.parent_object = row['doc']; d}}

            # For now empty merge. Since value of map function is transformed to object
            define_method :merge do |*args|
            end

            define_method :save do |callbacks=true|
              if !parent_object
                errors.add(name, 'no_parent')
                return false
              end
              if callbacks
                _run_save_callbacks do
                  parent_object.is_dirty if self.dirty?
                  parent_object.save
                end
              else
                parent_object.is_dirty if self.dirty?
                parent_object.save
              end
            end

            define_method name do |*args|
              local_options = args.last.is_a?(Hash) ? args.last : {}
              local_options.assert_valid_keys(:force_reload, :with_deleted)
              forced_reload = local_options[:force_reload] || false
              with_deleted = local_options[:with_deleted] || false
              return parent_object
            end
          
            define_method "#{name}=" do |value|
              klass = self.class.get_class_from_name(self.class._find_property(name).options[:class_name])
              raise ArgumentError, "expected #{klass} got #{value.class}" unless value.nil? || value.is_a?(klass)

              if value
                # Has many object update
                value_has_many_name = klass.properties.find{|p| p.is_a?(SimplyStored::Couch::HasManyEmbedded::Property) && p.options[:class_name] == self.class.name}.try(:name)
                value.send(value_has_many_name) << self unless !value_has_many_name || value.send(value_has_many_name).include?(self)

                # Has one object update
                #value_has_one_name = klass.properties.find{|p| p.is_a?(SimplyStored::Couch::HasOneEmbedded::Property) && p.options[:class_name] == self.class.name}.try(:name)
                #value.instance_variable_set("@#{value_has_one_name}", self) unless !value_has_one_name || value.send(value_has_one_name) == self
              end

              # Mark changed if appropriate
              send("#{name}_will_change!") if value != parent_object

              self.parent_object = value
              if value.nil?
                send("#{name}_id=", nil)
              else
                send("#{name}_id=", value.id)
              end
            end
          end
        end
        def build(object, json)
          object.send "#{name}_id=", json["#{name}_id"]
        end
      
        def serialize(json, object)
          json["#{name}_id"] = object.send("#{name}_id") if object.send("#{name}_id")
        end
        alias :value :serialize
            
        def association?
          true
        end
      end
    end
  end
end
