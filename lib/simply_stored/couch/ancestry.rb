module SimplyStored
  module Couch
    module Ancestry
      module InstanceMethods
        def children
          @children ||= self.class.database.view(self.class.children_view(:startkey => [id], :endkey => [id, {}], :reduce => false))
        end
        def children=(val)
          @children = val
          self.class.set_parents(self, @children)

          # Return wether all children can be saved :)
          @children.map(&:save).all?
        end

        def add_child(child)
          unless children.include?(child)
            @children ||= []
            @children += [child]
            child.parent = self
          end
        end

        # Get all descendants
        def descendants
          @descendants ||= self.class.database.view(self.class.subtree_view(:startkey => [id], :endkey => [id, {}], :reduce => false))
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

        def path
          ancestors + [self]
        end

        def depth
          (path_ids || [nil]).size - 1
        end
      end

      module TreeBuilder

      end

      def has_ancestry(options = {})
        options = {:order_by => :position}.merge(options)
        order_by = case options[:order_by]
                   when Symbol then "doc['#{options[:order_by]}']"
                   when Array then "[#{options[:order_by].map{|o| "doc['#{o}']"}.join(', ')}]"
                   else "doc['position']"
                   end
        property :path_ids, :type => Array, :default => []
        property :position, :type => Fixnum, :default => 0

        view :subtree_view, :type => :custom, :include_docs => true, :map => %|function(doc){
          if(doc['ruby_class'] == '#{name}' && doc.path_ids){
            for (var i in doc.path_ids){
              emit([doc.path_ids[i], doc.path_ids, #{order_by}], 1);
            }
          }
        }|, :reduce => "_sum"

        view :children_view, :type => :custom, :include_docs => true, :map => %|function(doc){
          if(doc['ruby_class'] == '#{name}' && doc.path_ids){
            emit([doc.path_ids.slice(-2,-1)[0], doc.path_ids, #{order_by}], 1);
          }
        }|, :reduce => "_sum"
        view :roots_view, :conditions => "doc.path_ids && doc.path_ids.length == 1", :key => options[:order_by]
        include SimplyStored::Couch::Ancestry::InstanceMethods
        before_update :update_tree_path
        after_create :create_tree_path
      end

      def roots(*args)
        database.view(roots_view(*args))
      end

      def full_tree(instances = all)
        build_tree(instances) #.first.children
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
              child = new(:id => child_id)
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
