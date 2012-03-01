module SimplyStored
  module Couch
    module Ancestry
      module InstanceMethods
        def children
          return @children if @children
          if root_property = self.class.ancestry_by_property
            @children = self.class.database.view(self.class.children_view(:startkey => [send(root_property), id], :endkey => [send(root_property), id, {}], :reduce => false))
          else
            @children = self.class.database.view(self.class.children_view(:startkey => [id], :endkey => [id, {}], :reduce => false))
          end
          @children
        end
        def children=(val)
          @old_descendants = descendants
          @children = val
          @children.map(&:subtree) # preload children hierarchy
          @new_descendants = []
          for child in @children
            for descendant in child.descendants
              @new_descendants << descendant
            end 
          end
          @old_descendants.each{|d| d.instance_variable_set('@parent', nil); d.path_ids = [d.id]} # old descendants become root
          (@old_descendants - @new_descendants).map(&:save) # Persist old descendants not present in new descendants

          # update by_property of children if it differs from parent (locale or ... orther field is required to have the same values)
          if root_property = self.class.ancestry_by_property
            self_by_property = send(root_property)
            for child in @children | @new_descendants
              child.send("#{root_property}=", self_by_property) if self_by_property != child.send(root_property)
            end
          end

          self.class.set_parent(self, @children) # recurring update of parent in subtree of children
          @descendants = (@children | @new_descendants)
          clear_cached_ancestors

          # Return wether all children can be saved :)
          (@descendants).map(&:save).all?
        end

        # reset cache attributes for ancestors
        def clear_cached_ancestors
          ansi = self
          while ancestor = ansi.instance_variable_get('@parent').presence
            ancestor.instance_variable_set('@descendants', nil)
            ancestor.instance_variable_set('@children', nil)
            ansi = ancestor
          end
          self
        end

        def add_child(child)
          unless children.include?(child)
            @children ||= []
            @children += [child]
            child.parent = self

            # update by_property of child if it differs from parent
            if root_property = self.class.ancestry_by_property
              child.send("#{root_property}=", send(root_property)) if send(root_property) != child.send(root_property)
            end
            @descendants = nil # reload descendants if requested
          end
          child
        end

        # Get all descendants
        def descendants
          return @descendants if @descendants
          if root_property = self.class.ancestry_by_property
            @descendants = self.class.database.view(self.class.subtree_view(:startkey => [send(root_property), id], :endkey => [send(root_property), id, {}], :reduce => false)).sort_by!{|d| [d.path_ids.size, d.position]}
          else
            @descendants = self.class.database.view(self.class.subtree_view(:startkey => [id], :endkey => [id, {}], :reduce => false)).sort_by{|d| [d.path_ids.size, d.position]}
          end
        end

        # Find subtree of a given page and set children with the result (important to get same children object ids as in descendants)
        def subtree
          @children = self.class.build_tree(descendants)
        end

        # Triggered before save
        def update_tree_path
          return false unless id
          newpath = ( (parent && parent.path_ids) || []) + [id]
          if path_ids != newpath
            path_ids_will_change!
            self.path_ids = newpath
          end
          self
        end

        # Triggered after create, because needs id
        def create_tree_path
          return false unless id
          newpath = ( (parent && parent.path_ids) || []) + [id]
          return true if path_ids == newpath
          self.path_ids = newpath
          save
        end

        def parent
          return @parent if @parent
          return @parent = self.class.find(parent_id) if parent_id.present?
          nil
        end

        def parent=(val)
          if @parent != val
            @parent = val
            @parent.children += [self] unless @parent.children.include?(self)
            update_tree_path
            save
          end
          val
        end

        def parent_id=(val)
          if parent_id != val.presence
            @parent = nil
            @parent_id = val.presence
            update_tree_path
          end
        end

        def parent_id
          @parent_id ||= parent_ids.last
        end

        def parent_ids
          (path_ids || [])[0..-2]
        end

        def ancestors
          return [] unless parent_ids.any?
          return [parent] if parent_ids.size == 1 # optimization, parent is pre-loaded many times
          (self.class.database.couchrest_database.bulk_load(parent_ids)['rows'] || []).map{|h| h['doc']}.compact
        end
        def parents
          ancestors
        end

        def tree_path
          ancestors + [self]
        end

        def tree_depth
          (path_ids || [nil]).size - 1
        end
      end

      module TreeBuilder

      end

      # Add ancestry logic to your model
      #   class Page
      #     include SimplyStored::Couch 
      #     has_ancestry
      #   end
      # or
      #   class Page
      #     include SimplyStored::Couch 
      #     property :locale
      #     has_ancestry :by_property => :locale
      #   end
      def has_ancestry(options = {})
        @ancestry_by_property = nil
        def self.ancestry_by_property
          @ancestry_by_property
        end
        options = {:order_by => :position}.merge(options)
        order_by = case options[:order_by]
                   when Symbol then "doc['#{options[:order_by]}']"
                   when Array then "[#{options[:order_by].map{|o| "doc['#{o}']"}.join(', ')}]"
                   else "doc['position']"
                   end
        property :path_ids, :type => Array, :default => []
        property :position, :type => Fixnum, :default => 0
        if options[:by_property].present?
          property options[:by_property] unless property_names.include?(options[:by_property])
          @ancestry_by_property = options[:by_property]
          by_property_view_prefix = options[:by_property].present? ? "doc['#{options[:by_property]}'], " : ''
        end

        view :subtree_view, :type => :custom, :include_docs => true, :map => %|function(doc){
          if(doc['ruby_class'] == '#{name}' && doc.path_ids){
            for(var i = 0; i < doc.path_ids.length - 1; i++){
              emit([#{by_property_view_prefix}doc.path_ids[i], doc.path_ids, #{order_by}], 1);
            }
          }
        }|, :reduce => "_sum"

        view :children_view, :type => :custom, :include_docs => true, :map => %|function(doc){
          if(doc['ruby_class'] == '#{name}' && doc.path_ids){
            emit([#{by_property_view_prefix}doc.path_ids.slice(-2,-1)[0], doc.path_ids, #{order_by}], 1);
          }
        }|, :reduce => "_sum"
        view :roots_view, :conditions => "doc.path_ids && doc.path_ids.length == 1", :key => [options[:by_property].presence, options[:order_by]].compact
        include SimplyStored::Couch::Ancestry::InstanceMethods
        extend SimplyStored::Couch::Ancestry::ClassMethods
        before_update :update_tree_path
        after_create :create_tree_path
      end
      module ClassMethods
        def roots(options = {})
          if root_property = ancestry_by_property
            if options.blank?
              options = {}
            elsif options.is_a?(Symbol)
              options = {:startkey => [options.to_s], :endkey => [options.to_s, {}]}
            elsif options.is_a?(String)
              options = {:startkey => [options], :endkey => [options, {}]}
            elsif options.keys.include?(root_property)
              root_key = options.delete(root_property)
              options[:startkey] = [root_key.to_s]
              options[:endkey] = [root_key.to_s, {}]
            end 
          end
          options[:reduce] = false
          database.view(roots_view(options))
        end

        def full_tree(options = {})
          if root_property = ancestry_by_property
            if options.blank?
              records = all
            elsif options.is_a?(Array)
              records = options
            elsif (options.is_a?(Symbol) || options.is_a?(String))
              records = send("find_all_by_#{root_property}", options.to_s)
            elsif options.is_a?(Hash) && options.keys.include?(root_property)
              root_key = options.delete(root_property)
              records = send("find_all_by_#{root_property}", root_key.to_s)
            else
              records = options[:records].presence || all
            end 
          else
            records = options.is_a?(Array) ? options : (options.present? && options[:records].presence) || all
          end
          build_tree(records) #.first.children
        end

        # Build a tree from a flat set of pages making use of the path attribute
        def build_tree(pages = nil)
          pages ||= all
          return pages if pages.empty? # Do not process empty array
          @tree_wrapper = OpenStruct.new(:children => []) # Dummy container as traversing begin, contains roots as children
          old_tree_slice = @tree_wrapper.children
          new_tree_slice = []
          pages.sort_by!{|p| [p.path_ids.size, p.position]}
          root_depth = pages.first.path_ids.size
          current_depth = root_depth + 1 # Start counting/swapping from one depth deeper than first one
          for page in pages
            old_tree_slice << page and next if page.path_ids.size == root_depth # fill first slice with roots

            # Move further if new depth is reached
            if page.path_ids.size > current_depth
              old_tree_slice = new_tree_slice
              new_tree_slice = []
            end
            parent = old_tree_slice.find{|r| r.id == page.path_ids[-2]} # path id before last is parent id
            next unless parent # page is not associated in tree

            # Initialize children if needed
            parent.instance_variable_set('@children', []) unless parent.instance_variable_get('@children').is_a?(Array)
            
            # Avoid database call on deepest children
            page.instance_variable_set('@children', []) unless page.instance_variable_get('@children').is_a?(Array)
            parent.instance_variable_get('@children') << page
            page.instance_variable_set('@parent', parent)
            page.instance_variable_set('@parent_id', parent.id)
            new_tree_slice << page
          end

          #TODO: setting @descendants from cache as option to avoid database call when descendants is required
          @tree_wrapper.children
        end

        # Recursive set parents
        def set_parent(parent, children)
          for child in children.sort_by!(&:position)
            child.instance_variable_set('@parent', parent)
            child.update_tree_path
            set_parent child, child.children 
          end
        end
      end
    end
  end
end
