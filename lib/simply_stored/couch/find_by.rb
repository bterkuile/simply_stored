module SimplyStored
  module Couch
    module FindBy
      include PaginationOptions
      def _define_find_by(name, *args)
        keys = name.to_s.gsub(/^find_by_/, "").split("_and_")
        view_name = name.to_s.gsub(/^find_/, "").to_sym
        view_keys = keys.length == 1 ? keys.first : keys
        without_deleted_view_name = "#{view_name}_withoutdeleted"
        without_deleted_view_keys = keys + [:deleted_at]
        
        unless respond_to?(view_name)
          puts "Warning: Defining view #{self.name}##{view_name} with keys #{view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[0]})"
          view(view_name, :key => view_keys)
        end
        
        if !respond_to?(without_deleted_view_name) && soft_deleting_enabled?
          puts "Warning: Defining view #{self.name}##{without_deleted_view_name} with keys #{without_deleted_view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[0]})"
          view(without_deleted_view_name, :key => without_deleted_view_keys)
        end
        
        (class << self; self end).instance_eval do
          define_method(name) do |*key_args|
            options = key_args.last.is_a?(Hash) ? key_args.pop : {}
            options.assert_valid_keys(:with_deleted)
            with_deleted = options.delete(:with_deleted)
            
            raise ArgumentError, "Too many or too few arguments, require #{keys.inspect}" unless keys.size == key_args.size            
            
            if soft_deleting_enabled? && !with_deleted
              key_args = key_args + [nil] # deleted_at
              database.view(send(without_deleted_view_name, :key => (key_args.size == 1 ? key_args.first : key_args), :limit => 1, :include_docs => true)).first
            else
              database.view(send(view_name, :key => (key_args.size == 1 ? key_args.first : key_args), :limit => 1, :include_docs => true)).first
            end
          end
        end
        
        send(name, *args)
      end
      
      def _define_find_all_by(name, *args)
        keys = name.to_s.gsub(/^find_all_by_/, "").split("_and_")
        view_name = name.to_s.gsub(/^find_all_/, "").to_sym
        count_name = name.to_s.gsub(/^find_all_/, 'count_').to_sym
        view_keys = keys.length == 1 ? keys.first : keys
        without_deleted_view_name = "#{view_name}_withoutdeleted"
        without_deleted_view_keys = keys + [:deleted_at]
        
        unless respond_to?(view_name)
          puts "Warning: Defining view #{self.name}##{view_name} with keys #{view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[0]})"
          view(view_name, :key => view_keys)
        end
        
        if !respond_to?(without_deleted_view_name) && soft_deleting_enabled?
          puts "Warning: Defining view #{self.name}##{without_deleted_view_name} with keys #{without_deleted_view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[0]})"
          view(without_deleted_view_name, :key => without_deleted_view_keys)
        end
        
        (class << self; self end).instance_eval do
          define_method(name) do |*key_args|
            options = key_args.last.is_a?(Hash) ? key_args.pop : {}
            with_pagination_options(options.update(:total_entries => send(count_name, *key_args))) do |options|
              options.assert_valid_keys(:with_deleted, :limit, :skip)
              with_deleted = options.delete(:with_deleted)
              
              raise ArgumentError, "Too many or too few arguments, require #{keys.inspect}" unless keys.size == key_args.size            
              
              if soft_deleting_enabled? && !with_deleted
                key_args = key_args + [nil] # deleted_at
                database.view(send(without_deleted_view_name, options.merge(:key => (key_args.size == 1 ? key_args.first : key_args)), :include_docs => true))
              else
                database.view(send(view_name, options.merge(:key => (key_args.size == 1 ? key_args.first : key_args), :include_docs => true)))
              end
            end
          end
        end
        send(name, *args)
      end
      
      def _define_count_by(name, *args)
        keys = name.to_s.gsub(/^count_by_/, "").split("_and_")
        view_name = name.to_s.gsub(/^count_/, "").to_sym
        view_keys = keys.length == 1 ? keys.first : keys
        without_deleted_view_name = "#{view_name}_withoutdeleted"
        without_deleted_view_keys = keys + [:deleted_at]
        
        unless respond_to?(view_name)
          puts "Warning: Defining view #{self.name}##{view_name} with keys #{view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[0]})"
          view(view_name, :key => view_keys)
        end
        
        if !respond_to?(without_deleted_view_name) && soft_deleting_enabled?
          puts "Warning: Defining view #{self.name}##{without_deleted_view_name} with keys #{without_deleted_view_keys.inspect} at call time, please add it to the class body. (Called from #{caller[0]})"
          view(without_deleted_view_name, :key => without_deleted_view_keys)
        end
        
        (class << self; self end).instance_eval do
          define_method("#{name}") do |*key_args|
            options = key_args.last.is_a?(Hash) ? key_args.pop : {}
            options.assert_valid_keys(:with_deleted)
            with_deleted = options.delete(:with_deleted)
            
            if soft_deleting_enabled? && !with_deleted
              key_args = key_args + [nil] # deleted_at
              database.view(send(without_deleted_view_name, :key => (key_args.size == 1 ? key_args.first : key_args), :reduce => true))
            else
              database.view(send(view_name, :key => (key_args.size == 1 ? key_args.first : key_args), :reduce => true))
            end
            
          end
        end
      
        send(name, *args)
      end
    end
  end
end
