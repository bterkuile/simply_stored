module SimplyStored
  module Couch
    module Ancestry
      module InstanceMethods
        def children
          return @children if @children.present?
          if root_property = self.class.ancestry_by_property
            @children = self.class.database.view(self.class.children_view(:startkey => [send(root_property), id], :endkey => [send(root_property), id, {}], :reduce => false))
          else
            @children = self.class.database.view(self.class.children_view(:startkey => [id], :endkey => [id, {}], :reduce => false))
          end
          @children
        end
        def children=(val)
          @children = val

          # update by_property of children if it differs from parent
          if root_property = self.class.ancestry_by_property
            self_by_property = send(root_property)
            for child in @children
              child.send("#{root_property}=", self_by_property) if self_by_property != child.send(root_property)
            end
          end

          self.class.set_parents(self, @children)
          @descendants = nil # reload descendants if requested

          # Return wether all children can be saved :)
          @children.map(&:save).all?
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
          return @descendants if @descendants.present?
          if root_property = self.class.ancestry_by_property
            @descendants = self.class.database.view(self.class.subtree_view(:startkey => [send(root_property), id], :endkey => [send(root_property), id, {}], :reduce => false))
          else
            @descendants = self.class.database.view(self.class.subtree_view(:startkey => [id], :endkey => [id, {}], :reduce => false))
          end
        end

        # Find subtree of a given page
        def subtree
          self.class.build_tree(descendants)
        end

        # Triggered before save
        def update_tree_path
          return false unless id
          newpath = ( (parent && parent.path_ids) || []) + [id]
          if path_ids != newpath
            path_ids_will_change!
            self.path_ids = newpath
          end
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
          return @parent = self.class.find(parent_id) if parent_id
          nil
        end

        def parent=(val)
          if @parent != val
            @parent = val
            @parent.children += [self] unless @parent.children.include?(self)
            update_tree_path
            save
          end
        end

        def parent_id=(val)
          if @parent_id != val
            @parent = nil
            @parent_id = val
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
          (self.class.database.couchrest_database.bulk_load(parent_ids)['rows'] || []).map{|h| h['doc']}.compact
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
            for (var i in doc.path_ids){
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
            if options.is_a?(Symbol)
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
            if options.is_a?(Array)
              records = options
            elsif options.is_a?(Symbol) || options.is_a?(String)
              records = send("find_all_by_#{root_property}", options.to_s)
            elsif options.keys.include?(root_property)
              root_key = options.delete(root_property)
              records = send("find_all_by_#{root_property}", root_key.to_s)
            else
              records = options[:records].presence || all
            end 
          else
            records = options.is_a?(Array) ? options : options[:records].presence || all
          end
          build_tree(records) #.first.children
        end

        # Build a tree from a flat set of pages making use of the path attribute
        def build_tree(pages = nil)
          pages ||= all
          res = OpenStruct.new(:children => []) # Dummy container as traversing begin, contains roots as children
          for page in pages
            current = res
            for child_id in page.path_ids
              child = current.children.find{|p| p.id == child_id}
              unless child
                child = pages.find{|p| p.id == child_id} || new(:id => child_id)
                current.children << child
              end
              current = child
            end
            # Update last child with actual page
            child.attributes = page.attributes 
            child._document = page._document
          end

          # Set the parents of all objects from 'cached' results
          for root in res.children.sort_by!(&:position)
            set_parents(root, root.children)
          end
          res.children
        end

        # Recursive set parents
        def set_parents(parent, children)
          for child in children.sort_by!(&:position)
            child.parent = parent
            set_parents child, child.children 
          end
        end
      end
    end
  end
end
