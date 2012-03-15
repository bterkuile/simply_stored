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
          :map_function => map_definition_without_deleted,
          :reduce_function => reduce_definition,
          :type => :custom,
          :include_docs => true
          
        map_definition_with_deleted = <<-eos
          function(doc) { 
            if (doc['ruby_class'] == '#{self.to_s}' && doc['#{name.to_s}_id'] != null) {
              emit([doc.#{name.to_s}_id, doc.created_at], 1);
            }
          }
        eos
         
        view "association_#{self.name.underscore.gsub('/', '__')}_embedded_in_#{name}_with_deleted",
          :map_function => map_definition_with_deleted,
          :reduce_function => reduce_definition,
          :type => :custom,
          :include_docs => true
            
        properties << SimplyStored::Couch::EmbeddedIn::Property.new(self, name, options)
      end

      class Property #:nodoc:
        attr_accessor :name, :options
      
        def initialize(owner_clazz, name, options = {})
          @name = name
          embedded_in_name = name
          @options = {
            :class_name => name.to_s.singularize.camelize
          }.update(options)

          @options.assert_valid_keys(:class_name)

          # For now restrictions on naming
          parent_property_name = owner_clazz.name.property_name.pluralize

          owner_clazz.class_eval do
            property :"#{name}_id"
            attr_accessor :parent_object
            property :index
            @@embedded_in_class_name = name.to_s.camelize

            class << self

              define_method :embedded_in_class_name do
              #  embedded_in_name.to_s.singularize.camelize
                @@embedded_in_class_name
              end

              define_method :belongs_to do |belongs_to_name, *args|
                super(*([belongs_to_name] + args))
                # Now override belongs to view
                view "association_#{foreign_property}_belongs_to_#{belongs_to_name}",
                  :map_function => %|function(doc){if(doc['ruby_class'] == '#{embedded_in_class_name}' && doc['#{self.name.property_name.pluralize}']){
                    for(var i in doc.#{self.name.property_name.pluralize}){
                      if(doc['#{self.name.property_name.pluralize}'][i]['#{belongs_to_name.to_s.foreign_key}']){
                        emit([doc['#{self.name.property_name.pluralize}'][i]['#{belongs_to_name.to_s.foreign_key}'], doc['created_at']], doc['#{self.name.property_name.pluralize}'][i]);
                      }
                    }
                  }}|,
                  :reduce_function => %|function(key, values){return values.length}|,
                  :type => :raw,
                  :results_filter => lambda{|results| results['rows'].map{|row| d = row['value']; d.parent_object = row['doc']; d.parent_object.send(self.name.property_name.pluralize)[d.index]}},
                  :include_docs => true
              end

              define_method :count do |options = {}|
                database.view(all_documents_for_count(options.merge(:reduce => true)))['rows'].try(:first).try('[]', 'value').to_i
              end
            end

            # Make parent object send through original for callbacks
            define_method :parent_object= do |value|
              return @parent_object if @parent_object && @parent_object == value
              @parent_object = value # Prevent circular calls
              send("#{name}=", value)
            end
            # Redefine the equality method, since we are different kind of objects
            define_method "==" do |value|
              self.class == value.class && (value.respond_to?(:parent_object) && self.parent_object == value.parent_object) && (value.respond_to?(:index) && self.index == value.index)
            end
            view :all_documents_for_count, :type => :raw, :include_docs => false, :map_function => %|function(doc){
              if(doc['ruby_class'] == '#{name.to_s.singularize.camelize}' && typeof(doc['#{parent_property_name}']) == 'object'){
                for(var i=0; i < doc['#{parent_property_name}'].length; i++){
                  emit(doc['#{parent_property_name}'][i]['created_at'], 1);
                }
              }
            }|, :reduce_function => '_sum'
            view :all_documents, :type => :raw, :include_docs => true, :map_function => %|function(doc){
              if(doc['ruby_class'] == '#{name.to_s.singularize.camelize}' && typeof(doc['#{parent_property_name}']) == 'object'){
                for(var i=0; i < doc['#{parent_property_name}'].length; i++){
                  emit(doc['#{parent_property_name}'][i]['created_at'], doc['#{parent_property_name}'][i]);
                }
              }
            }|, :results_filter => lambda{|results| results['rows'].map{|row| d = row['value']; d.parent_object = row['doc']; d.parent_object.send(parent_property_name)[d.index]}}

            

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
              return value if instance_variable_get("@#{name}") == value
              klass = self.class.get_class_from_name(name)
              raise ArgumentError, "expected #{klass} got #{value.class}" unless value.nil? || value.is_a?(klass)

              if value
                # Has many object update
                value_has_many_name = klass.properties.find{|p| p.is_a?(SimplyStored::Couch::HasManyEmbedded::Property) && p.options[:class_name] == self.class.name}.try(:name)
                value.send("add_#{value_has_many_name.to_s.singularize}", self) unless !value_has_many_name || value.send(value_has_many_name).include?(self)

                # Has one object update
                #value_has_one_name = klass.properties.find{|p| p.is_a?(SimplyStored::Couch::HasOneEmbedded::Property) && p.options[:class_name] == self.class.name}.try(:name)
                #value.instance_variable_set("@#{value_has_one_name}", self) unless !value_has_one_name || value.send(value_has_one_name) == self
              end

              # Mark changed if appropriate
              send("#{name}_will_change!") if value != parent_object

              instance_variable_set('@parent_object', value)
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
      end # Property
    end
  end
end
