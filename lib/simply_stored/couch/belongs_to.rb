# Gracefully taken from CouchPotato after it has been removed for good.
module SimplyStored
  module Couch
    module BelongsTo
      include SimplyStored::Couch::Properties

      def belongs_to(name, options = {})
        check_existing_properties(name, SimplyStored::Couch::BelongsTo::Property)
        association_property = if name.to_s.index('__')
                                 # Already defined properly
                                 name
                               elsif rindex = foreign_property.to_s.rindex('__')
                                 "#{foreign_property[0...rindex]}__#{name}"
                               else
                                 name
                               end

        map_definition_without_deleted = <<-eos
          function(doc) { 
            if (doc['ruby_class'] == '#{self.to_s}' && doc['#{name}_id'] != null) {
              if (doc['#{soft_delete_attribute}'] && doc['#{soft_delete_attribute}'] != null){
                // "soft" deleted
              }else{
                emit([doc.#{name}_id, doc.created_at], 1);
              }
            }
          }
        eos
        
        reduce_definition = "_sum"
        view "association_#{foreign_property}_belongs_to_#{association_property}",
          :map => map_definition_without_deleted,
          :reduce => reduce_definition,
          :type => "custom",
          :include_docs => true
          
        map_definition_with_deleted = <<-eos
          function(doc) { 
            if (doc['ruby_class'] == '#{self.to_s}' && doc['#{name}_id'] != null) {
              emit([doc.#{name}_id, doc.created_at], 1);
            }
          }
        eos
         
        view "association_#{foreign_property}_belongs_to_#{association_property}_with_deleted",
          :map => map_definition_with_deleted,
          :reduce => reduce_definition,
          :type => "custom",
          :include_docs => true
            
        properties << SimplyStored::Couch::BelongsTo::Property.new(self, name, options)
      end

      class Property #:nodoc:
        attr_accessor :name, :options
      
        def initialize(owner_clazz, name, options = {})
          @name = name
          @options = {
            :class_name => owner_clazz.find_association_class_name(name)
          }.update(options)

          @options.assert_valid_keys(:class_name)

          owner_clazz.class_eval do
            property :"#{name}_id"
            
            define_method name do |*args|
              local_options = args.last.is_a?(Hash) ? args.last : {}
              local_options.assert_valid_keys(:force_reload, :with_deleted)
              forced_reload = local_options[:force_reload] || false
              with_deleted = local_options[:with_deleted] || false
              
              return instance_variable_get("@#{name}") unless instance_variable_get("@#{name}").nil? or forced_reload

              if send("#{name}_id").present?
                # Try to fetch the object. Does not have to be present. When relation dependency is ignore, the id remains.
                # This will result in a id to a non existent object. Therefore the rescue for object
                object = self.class.get_class_from_name(name).find(send("#{name}_id"), :with_deleted => with_deleted) rescue nil
                instance_variable_set("@#{name}",  object)
              else
                instance_variable_set("@#{name}",  nil)
              end
            end
          
            define_method "#{name}=" do |value|
              klass = self.class.get_class_from_name(name)
              raise ArgumentError, "expected #{klass} got #{value.class}" unless value.nil? || value.is_a?(klass)

              if value
                # Has many object update
                value_has_many_name = klass.properties.find{|p| p.is_a?(SimplyStored::Couch::HasMany::Property) && p.options[:class_name] == self.class.name}.try(:name)
                value.send(value_has_many_name) << self unless !value_has_many_name || value.send(value_has_many_name).include?(self)

                # Has one object update
                value_has_one_name = klass.properties.find{|p| p.is_a?(SimplyStored::Couch::HasOne::Property) && p.options[:class_name] == self.class.name}.try(:name)
                value.instance_variable_set("@#{value_has_one_name}", self) unless !value_has_one_name || value.send(value_has_one_name) == self
              end

              # Mark changed if appropriate
              send("#{name}_will_change!") if value != instance_variable_get("@#{name}")

              instance_variable_set("@#{name}", value)
              if value.nil?
                send("#{name}_id=", nil)
              else
                send("#{name}_id=", value.id)
              end
            end

            define_method "#{name}_id=" do |new_foreign_id|
              super(new_foreign_id)
              value = instance_variable_get("@#{name}")
              remove_instance_variable("@#{name}") if instance_variable_defined?("@#{name}") && new_foreign_id != value.try(:id)
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
