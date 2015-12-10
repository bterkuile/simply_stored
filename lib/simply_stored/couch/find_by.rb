module SimplyStored
  module Couch
    module FindBy
      include PaginationOptions
      def _define_find_by(name, *args)
        raise_when_not_found = name.to_s.end_with?('!')
        name = name.to_s.chop.to_sym if raise_when_not_found
        keys = name.to_s.sub(/^find_by_/, "").split("_and_").map(&:to_sym)

        # replace asociation assignments with their property values if possible
        keys.each.with_index do |key, i|
          if properties.find{|p| p.name.to_sym == key.to_sym}.is_a?(SimplyStored::Couch::BelongsTo::Property)
            keys[i] = "#{keys[i]}_id"
          end
        end

        view_name = name.to_s.sub(/^find_/, "").to_sym
        view_keys = keys.length == 1 ? keys.first : keys
        without_deleted_view_name = "#{view_name}_withoutdeleted"
        without_deleted_view_keys = keys + [:deleted_at]


        unless respond_to?(view_name)
          puts "Warning: Defining view #{self.name}##{view_name} with keys #{view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[1]})"
          view(view_name, key: view_keys)
        end

        if !respond_to?(without_deleted_view_name) && soft_deleting_enabled?
          puts "Warning: Defining view #{self.name}##{without_deleted_view_name} with keys #{without_deleted_view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[1]})"
          view(without_deleted_view_name, key: without_deleted_view_keys)
        end
        if raise_when_not_found
          (class << self; self end).instance_eval do
            define_method(:"#{name}!") do |*key_args|
              options = key_args.last.is_a?(Hash) ? key_args.pop : {}
              options.assert_valid_keys(:with_deleted)
              with_deleted = options.delete(:with_deleted)

              raise ArgumentError, "Too many or too few arguments, require #{keys.inspect}" unless keys.size == key_args.size

              key_args.map!{|a| a.is_a?(SimplyStored::Couch) ? a.id : a}

              if soft_deleting_enabled? && !with_deleted
                key_args = key_args + [nil] # deleted_at
                result = database.view(send(without_deleted_view_name, key: (key_args.size == 1 ? key_args.first : key_args), limit: 1, include_docs: true)).first
              else
                result = database.view(send(view_name, key: (key_args.size == 1 ? key_args.first : key_args), limit: 1, include_docs: true)).first
              end
              raise SimplyStored::RecordNotFound unless result
              result
            end
          end
          send(:"#{name}!", *args)
        else
          (class << self; self end).instance_eval do
            define_method(name) do |*key_args|
              options = key_args.last.is_a?(Hash) ? key_args.pop : {}
              options.assert_valid_keys(:with_deleted)
              with_deleted = options.delete(:with_deleted)

              raise ArgumentError, "Too many or too few arguments, require #{keys.inspect}" unless keys.size == key_args.size

              key_args.map!{|a| a.is_a?(SimplyStored::Couch) ? a.id : a}

              if soft_deleting_enabled? && !with_deleted
                key_args = key_args + [nil] # deleted_at
                database.view(send(without_deleted_view_name, key: (key_args.size == 1 ? key_args.first : key_args), limit: 1, include_docs: true)).first
              else
                database.view(send(view_name, key: (key_args.size == 1 ? key_args.first : key_args), limit: 1, include_docs: true)).first
              end
            end
          end
          send(name, *args)
        end
      end

      def _define_find_all_by(name, *args)
        raise_when_not_found = name.to_s.end_with?('!')
        name = name.to_s.chop.to_sym if raise_when_not_found
        keys = name.to_s.sub(/^find_all_by_/, "").split("_and_")

        # replace asociation assignments with their property values if possible
        keys.each.with_index do |key, i|
          if properties.find{|p| p.name.to_sym == key.to_sym}.is_a?(SimplyStored::Couch::BelongsTo::Property)
            keys[i] = "#{keys[i]}_id"
          end
        end

        view_name = name.to_s.sub(/^find_all_/, "").to_sym
        count_name = name.to_s.sub(/^find_all_/, 'count_').to_sym
        view_keys = keys.length == 1 ? keys.first : keys
        without_deleted_view_name = "#{view_name}_withoutdeleted"
        without_deleted_view_keys = keys + [:deleted_at]

        unless respond_to?(view_name)
          puts "Warning: Defining view #{self.name}##{view_name} with keys #{view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[1]})"
          view(view_name, key: view_keys)
        end

        if !respond_to?(without_deleted_view_name) && soft_deleting_enabled?
          puts "Warning: Defining view #{self.name}##{without_deleted_view_name} with keys #{without_deleted_view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[1]})"
          view(without_deleted_view_name, key: without_deleted_view_keys)
        end

        if raise_when_not_found
          (class << self; self end).instance_eval do
            define_method(:"#{name}!") do |*key_args|
              options = key_args.last.is_a?(Hash) ? key_args.pop : {}
              with_pagination_options(options.update(total_entries: send(count_name, *key_args))) do |options|
                options.assert_valid_keys(:with_deleted, :limit, :skip, :keys)
                with_deleted = options.delete(:with_deleted)

                key_args.map!{|a| a.is_a?(SimplyStored::Couch) ? a.id : a}
                options[:key] = key_args.first if key_args.size == 1
                options[:key] = key_args if key_args.size > 1
                options[:include_docs] = true

                raise ArgumentError, "Too many or too few arguments, require #{keys.inspect}" unless keys.size == key_args.size || options[:keys]

                key_args.map!{|a| a.is_a?(SimplyStored::Couch) ? a.id : a}

                if soft_deleting_enabled? && !with_deleted
                  options[:key] = Array.wrap(options[:key]) + [nil] # deleted_at
                  result = database.view(send(without_deleted_view_name, options))
                else
                  result = database.view(send(view_name, options))
                end
                raise SimplyStored::RecordNotFound unless result && result.any?
                result
              end
            end
          end
          send(:"#{name}!", *args)
        else
          (class << self; self end).instance_eval do
            define_method(name) do |*key_args|
              options = key_args.last.is_a?(Hash) ? key_args.pop : {}
              with_pagination_options(options.update(total_entries: send(count_name, *key_args))) do |options|
                options.assert_valid_keys(:with_deleted, :limit, :skip, :keys)
                with_deleted = options.delete(:with_deleted)

                key_args.map!{|a| a.is_a?(SimplyStored::Couch) ? a.id : a}
                options[:key] = key_args.first if key_args.size == 1
                options[:key] = key_args if key_args.size > 1
                options[:include_docs] = true

                raise ArgumentError, "Too many or too few arguments, require #{keys.inspect}" unless keys.size == key_args.size || options[:keys]

                if soft_deleting_enabled? && !with_deleted
                  options[:key] = Array.wrap(options[:key]) + [nil] # deleted_at
                  database.view(send(without_deleted_view_name, options))
                else
                  database.view(send(view_name, options))
                end
              end
            end
          end
          send(name, *args)
        end
      end

      def _define_count_by(name, *args)
        keys = name.to_s.sub(/^count_by_/, "").split("_and_")
        view_name = name.to_s.sub(/^count_/, "").to_sym
        view_keys = keys.length == 1 ? keys.first : keys
        without_deleted_view_name = "#{view_name}_withoutdeleted"
        without_deleted_view_keys = keys + [:deleted_at]

        unless respond_to?(view_name)
          puts "Warning: Defining view #{self.name}##{view_name} with keys #{view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[1]})"
          view(view_name, key: view_keys)
        end

        if !respond_to?(without_deleted_view_name) && soft_deleting_enabled?
          puts "Warning: Defining view #{self.name}##{without_deleted_view_name} with keys #{without_deleted_view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[1]})"
          view(without_deleted_view_name, key: without_deleted_view_keys)
        end

        (class << self; self end).instance_eval do
          define_method("#{name}") do |*key_args|
            options = key_args.last.is_a?(Hash) ? key_args.pop : {}
            options.assert_valid_keys(:with_deleted, :keys)
            with_deleted = options.delete(:with_deleted)
            options[:key] = key_args.first if key_args.size == 1
            options[:key] = key_args if key_args.size > 1
            options[:reduce] = true

            if soft_deleting_enabled? && !with_deleted
              options[:key] = Array.wrap(options[:key]) + [nil] # deleted_at
              database.view(send(without_deleted_view_name, options))
            else
              database.view(send(view_name, options))
            end

          end
        end

        send(name, *args)
      end
    end
  end
end
