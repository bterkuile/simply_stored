module SimplyStored
  module Couch
    module HasOne
      def has_one(name, options = {})
        check_existing_properties(name, SimplyStored::Couch::HasOne::Property)
        properties << SimplyStored::Couch::HasOne::Property.new(self, name, options)
      end
      
      def define_has_one_setter(name, options)
        define_method("#{name}=") do |value|
          klass = self.class.get_class_from_name(name)
          raise ArgumentError, "expected #{klass} got #{value.class}" unless value.nil? || value.is_a?(klass)
          old_value = send("#{name}", :force_reload => true)
          if value.nil?
            instance_variable_set("@#{name}", nil)
          else
            instance_variable_set("@#{name}", value)
            value.send("#{self.class.foreign_key}=", id)
            value.save
          end
          
          if old_value
            if options[:dependent] == :destroy
              old_value.destroy
            else
              old_value.send("#{self.class.foreign_property}=", nil)
              old_value.save
            end
          end
          old_value
        end
      end
      
      def define_has_one_getter(name, options)
        define_method(name) do |*args|
          local_options = args.first && args.first.is_a?(Hash) && args.first
          forced_reload, with_deleted, limit, descending = extract_association_options(local_options)

          if forced_reload || instance_variable_get("@#{name}").nil?
            found_object = find_one_associated(options[:class_name], self.class, :with_deleted => with_deleted, :foreign_key => options[:foreign_key])
            instance_variable_set("@#{name}", found_object)
            self.class.set_parent_has_one_association_object(self, found_object)
          end
          instance_variable_get("@#{name}")
        end
      end
      
      def set_parent_has_one_association_object(parent, child)
        if child.respond_to?("#{parent.class.name.to_s.singularize.downcase}=")
          child.send("#{parent.class.name.to_s.singularize.camelize.downcase}=", parent)
        end
      end
      
      class Property < SimplyStored::Couch::AssociationProperty
      
        def initialize(owner_clazz, name, options = {})
          options = {
            :dependent => :nullify,
            :class_name => name.to_s.singularize.camelize,
            :foreign_key => nil
          }.update(options)
          @name, @options = name, options
          
          options.assert_valid_keys(:dependent, :class_name, :foreign_key)
          
          owner_clazz.class_eval do
            define_has_one_getter(name, options)
            define_has_one_setter(name, options)
          end
        end

      end
    end
  end
end
