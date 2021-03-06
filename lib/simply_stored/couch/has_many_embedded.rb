module SimplyStored
  module Couch
    module HasManyEmbedded
      def has_many_embedded(name, options = {})
        check_existing_properties(name, SimplyStored::Couch::HasMany::Property)
        properties << SimplyStored::Couch::HasManyEmbedded::Property.new(self, name, options)
      end

      def define_has_many_embedded_getter(name, options)
        # Make an alias to the property getter.
        property_getter_method = "#{name}_property_getter"
        alias_method property_getter_method, name
        define_method(name) do |*args|
          current = instance_variable_get("@#{name}")
          return  current if current && current.respond_to?(:parent_object_set?)
          # Rebuild current, ensure parent object
          current = Array.wrap(self.send(property_getter_method)).map do |h|
            if h.is_a?(options[:class_name].constantize)
              o = h
              o.parent_object = self
            else
              o = options[:class_name].constantize.new
              o._document = h
              o.parent_object = self
            end
            o
          end
          def current.parent_object_set?
            true
          end
          instance_variable_set("@#{name}", current)
          return current
          local_options = args.first && args.first.is_a?(Hash)
          forced_reload, with_deleted, limit, descending = extract_association_options(local_options)

          cached_results = send("_get_cached_#{name}") || {}
          cache_key = _cache_key_for(local_options)
          debugger
          if forced_reload || cached_results[cache_key].nil? 
            #cached_results[cache_key] = get_embedded(options[:class_name], self.class, :with_deleted => with_deleted, :limit => limit, :descending => descending, :foreign_key => options[:foreign_key])
            cached_results[cache_key] = Array.wrap(self.send(property_getter_method)).map{|h| o = options[:class_name].constantize.new; o._document = h; o}.map{|o| o.parent_object = self; o}
            instance_variable_set("@#{name}", cached_results)
            self.class.set_parent_has_many_embedded_association_object(self, cached_results[cache_key])
          end
          cached_results[cache_key]
        end
      end

      def define_has_many_embedded_setter(name, options)
        define_method("#{name}=") do |values|
          klass = self.class.get_class_from_name(name)
          raise ArgumentError, "expected Array got #{values.class}" unless values.is_a?(Array)
          instance_variable_set("@#{name}", []) unless instance_variable_get("@#{name}")
          iid = 0
          for value in values
            if value.is_a?(Hash)
              newval = klass.new
              newval._document = value
              newval.updated_at ||= Time.now
              newval.created_at ||= Time.now
            else
              newval = value
            end
            newval.index = iid
            instance_variable_get("@#{name}") << newval
            iid += 1
          end
          save
        end
      end

      def define_has_many_embedded_setter_add(name, options)
        define_method("add_#{name.to_s.singularize}") do |value|
          klass = self.class.get_class_from_name(name)
          raise ArgumentError, "expected #{klass} got #{value.class}" unless value.is_a?(klass)
          if value.is_a?(Hash)
            newval = klass.new
            newval._document = value
            newval.updated_at ||= Time.now
            newval.created_at ||= Time.now
          else
            newval = value
          end
          newval.index = (instance_variable_get("@#{name}") || []).size
          instance_variable_get("@#{name}") << newval
          save
        end
      end

      def define_has_many_embedded_setter_remove(name, options)
        define_method "remove_#{name.to_s.singularize}" do |value|
          klass = self.class.get_class_from_name(name)
          if value.is_a?(klass)
            found = instance_variable_get("@#{name}").delete(value)
            if found
              self.is_dirty
              self.send("reset_#{name}_index_values")
            end
          else
            raise ArgumentError, "expected #{klass} got #{value.class}"
          end
          return save
        end
      end


      def define_reset_index_values(name, options)
        define_method "reset_#{name}_index_values" do
          i = 0
          for embedded_document in (instance_variable_get("@#{name}") || [])
            embedded_document.index = i
            i += 1 
          end
        end
      end

     # Not converted yet 
      def define_has_many_embedded_setter_remove_all(name, options)
        define_method "remove_all_#{name}" do
          all = send("#{name}", :force_reload => true)
          
          all.collect{|i| i}.each do |item|
            send("remove_#{name.to_s.singularize}", item)
          end
        end
      end
      
     # Not converted yet 
      def define_has_many_embedded_count(name, options, through = nil)
        method_name = name.to_s.singularize.underscore.gsub('/', '__') + "_count"
        define_method(method_name) do |*args|
          local_options = args.first && args.first.is_a?(Hash) && args.first
          if local_options
            local_options.assert_valid_keys(:force_reload, :with_deleted)
            forced_reload = local_options[:force_reload]
            with_deleted = local_options[:with_deleted]
          else
            forced_reload = false
            with_deleted = false
          end

          if forced_reload || instance_variable_get("@#{method_name}").nil?
            instance_variable_set("@#{method_name}", count_associated(through || options[:class_name], self.class, :with_deleted => with_deleted, :foreign_key => options[:foreign_key]))
          end
          instance_variable_get("@#{method_name}")
        end
      end
      
     # Not converted yet 
      def set_parent_has_many_embedded_association_object(parent, child_collection)
        child_collection.each do |child|
          if child.respond_to?("#{parent.class.name.to_s.singularize.downcase}=")
            child.send("#{parent.class.name.to_s.singularize.camelize.downcase}=", parent)
          end
        end
      end
      
      class Property < SimplyStored::Couch::AssociationProperty
        
        def initialize(owner_clazz, name, options = {})
          options = {
            :dependent => :nullify,
            :through => nil,
            :class_name => name.to_s.singularize.camelize,
            :foreign_key => nil
          }.update(options)
          @name, @options = name, options
          
          options.assert_valid_keys(:dependent, :through, :class_name, :foreign_key)
          
          owner_clazz.class_eval do
            property name, :type => Array
            _define_cache_accessors(name, options)
            define_has_many_embedded_getter(name, options)
            define_has_many_embedded_setter(name, options)
            define_has_many_embedded_setter_add(name, options)
            define_has_many_embedded_setter_remove(name, options)
            define_has_many_embedded_setter_remove_all(name, options)
            define_reset_index_values(name, options)
            define_has_many_embedded_count(name, options)
          end
        end
        
      end
    end
  end
end
