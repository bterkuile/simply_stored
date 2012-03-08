require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')

class AncestryTest < Test::Unit::TestCase
  context "standard with hierarchy" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
      @d1 = Directory.create(name: 'dir1', position: 0)
      @d2 = Directory.create(name: 'dir2', position: 1)
      @d3 = Directory.create(name: 'dir3', position: 2)
      @d4 = Directory.create(name: 'dir4', position: 3)
      @a = [@d1, @d2, @d3, @d4]
    end

    should "be invalid if make_invalid is an option" do
      assert_equal false, @d1.update_attributes(:make_invalid => true) 
    end

    should "all have a path containing own id" do
      assert_equal @a.map(&:id), @a.map(&:path_ids).flatten
    end
    
    should "set valid children when mass assigned" do
      @d1.children = [@d2, @d3]
      assert_equal [@d2.id, @d3.id].sort, @d1.children.map(&:id).sort
      assert_equal [@d1.id, @d2.id], @d2.path_ids
      d1_reloaded = Directory.find(@d1.id)
      assert_equal [@d2.name, @d3.name].sort, d1_reloaded.children.map(&:name).sort
      assert_equal [@d1.id, @d2.id], d1_reloaded.children.sort_by(&:name).first.path_ids
    end

    should "be valid when parent is assigned" do
      @d1.children = [@d2, @d3] # See previous test for this one
      @d4.parent = @d2 # This is the functionality to be tested here

      assert_equal [@d4], @d2.children
      assert_equal @d2, @d4.parent
      assert_equal [@d1.id, @d2.id, @d4.id], @d4.path_ids

      # Also test database values
      d2_reloaded = Directory.find(@d2.id)
      d4_reloaded = Directory.find(@d4.id)
      assert_equal [@d4], d2_reloaded.children
      assert_equal @d2, d4_reloaded.parent
      assert_equal [@d1.id, @d2.id, @d4.id], d4_reloaded.path_ids
    end

    should "handle roots" do
      assert_equal @a.sort_by(&:id), Directory.roots.sort_by(&:id)
      @d1.children = [@d2, @d3]
      assert_equal [@d1.id, @d4.id].sort, Directory.roots.map(&:id).sort
    end

    should "give proper ancestors" do
      @d1.children = [@d2, @d3]
      @d3.add_child(@d4).save
      assert_equal [], @d1.ancestors
      assert_equal [@d1], @d2.ancestors
      assert_equal [@d1], @d3.ancestors
      assert_equal [@d1, @d3], @d4.ancestors
      d4_reloaded = Directory.find(@d4.id)
      assert_equal [@d1, @d3], d4_reloaded.ancestors
    end

    should "give proper descendants" do
      @d1.children = [@d2, @d3]
      @d2.children = [@d4]
      assert_equal [@d2, @d3, @d4], @d1.descendants.sort_by(&:name)
    end

    should "give a proper subtree and does not change the subject" do
      # This is a relevant test since it failed in the past
      @d1.children = [@d2]
      @d2.children = [@d3, @d4]
      assert_equal [@d3, @d4], @d2.subtree
      @d2.reload
      # This is what it is about
      assert_equal [@d1.id, @d2.id], @d2.path_ids
    end

    should "update path_ids on deeper nested elements using children=" do
      @d2.children = [@d3, @d4]
      @d1.children = [@d2]

      # Not for now, objects self are not updated
      #assert_equal [@d1.id, @d2.id, @d3.id], @d3.path_ids
      #assert_equal [@d1.id, @d2.id, @d4.id], @d4.path_ids
      @d3.reload
      @d4.reload
      assert_equal [@d1.id, @d2.id, @d3.id], @d3.path_ids
      assert_equal [@d1.id, @d2.id, @d4.id], @d4.path_ids
    end
    should "update path_ids on deeper nested elements using parent_id=" do
      @d2.children = [@d3, @d4]
      [@d2, @d3, @d4].map(&:reload)
      @d2.parent_id = @d1.id

      # Not for now, objects self are not updated
      #assert_equal [@d1.id, @d2.id, @d3.id], @d3.path_ids
      #assert_equal [@d1.id, @d2.id, @d4.id], @d4.path_ids
      @d3.reload
      @d4.reload
      assert_equal [@d1.id, @d2.id, @d3.id], @d3.path_ids
      assert_equal [@d1.id, @d2.id, @d4.id], @d4.path_ids
    end
    should "update path_ids on deeper nested elements using parent_id= nil" do
      # Copy of previous
      @d2.children = [@d3, @d4]
      [@d2, @d3, @d4].map(&:reload)
      @d2.parent_id = @d1.id

      # Not for now, objects self are not updated
      #assert_equal [@d1.id, @d2.id, @d3.id], @d3.path_ids
      #assert_equal [@d1.id, @d2.id, @d4.id], @d4.path_ids
      [@d2, @d3, @d4].map(&:reload)
      assert_equal [@d1.id, @d2.id, @d3.id], @d3.path_ids
      assert_equal [@d1.id, @d2.id, @d4.id], @d4.path_ids

      @d2.parent_id = ""
      [@d2, @d3, @d4].map(&:reload)
      assert_equal [@d2.id, @d3.id], @d3.path_ids
      assert_equal [@d2.id, @d4.id], @d4.path_ids
    end

    should "preserve children of parent when another is added through parent_id=" do
      # Yes, this one failed once

      # Copy of previous
      @d2.children = [@d3]
      [@d2, @d3, @d4].map(&:reload)
      @d4.parent_id = @d2.id
      [@d2, @d3, @d4].map(&:reload)
      assert_equal [@d3, @d4], @d2.children
    end
    should "not update descendants when parent_id is set in update_attributes and save is not valid" do
      # Copy of previous
      @d2.children = [@d3, @d4]
      [@d2, @d3, @d4].map(&:reload)
      @d2.update_attributes(:parent_id => @d1.id, :make_invalid => true)

      [@d1, @d2, @d3, @d4].map(&:reload)
      assert_equal [@d2.id, @d3.id], @d3.path_ids
      assert_equal [@d2.id, @d4.id], @d4.path_ids

    end

    should 'build tree returning actual objects set in descendants' do
      @d1.children = [@d2, @d3]
      [@d1, @d2, @d3].map(&:reload)
      assert_equal @d1.subtree.map(&:object_id).sort, @d1.descendants.map(&:object_id).sort
    end
  end
  context "namespaced with hierarchy" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
      @d1 = NamespacedDirectory.create(:name => 'dir1', :locale => 'en')
      @d2 = NamespacedDirectory.create(:name => 'dir2', :locale => 'en')
      @d3 = NamespacedDirectory.create(:name => 'dir3', :locale => 'nl')
      @d4 = NamespacedDirectory.create(:name => 'dir4', :locale => 'nl')
      @a = [@d1, @d2, @d3, @d4]
    end

    should "all have a path containing own id" do
      assert_equal @a.map(&:id), @a.map(&:path_ids).flatten
    end
    
    should "set valid children when mass assigned" do
      @d1.children = [@d2, @d3]
      assert_equal [@d2.id, @d3.id].sort, @d1.children.map(&:id).sort
      assert_equal [@d1.id, @d2.id], @d2.path_ids
      d1_reloaded = NamespacedDirectory.find(@d1.id)
      assert_equal [@d2.name, @d3.name].sort, d1_reloaded.children.map(&:name).sort
      assert_equal [@d1.id, @d2.id], d1_reloaded.children.sort_by(&:name).first.path_ids
    end

    should "be valid when parent is assigned" do
      @d1.children = [@d2, @d3] # See previous test for this one
      @d4.parent = @d2 # This is the functionality to be tested here

      assert_equal [@d4], @d2.children
      assert_equal @d2, @d4.parent
      assert_equal [@d1.id, @d2.id, @d4.id], @d4.path_ids

      # Also test database values
      d2_reloaded = NamespacedDirectory.find(@d2.id)
      d4_reloaded = NamespacedDirectory.find(@d4.id)
      assert_equal [@d4], d2_reloaded.children
      assert_equal @d2, d4_reloaded.parent
      assert_equal [@d1.id, @d2.id, @d4.id], d4_reloaded.path_ids
    end

    should "return proper parents" do
      @d1.children = [@d2, @d3]
      @d2.children = [@d4]
      assert_equal [@d1, @d2], @d4.parents
    end

    should "handle roots" do
      assert_equal @a.sort_by(&:id), NamespacedDirectory.roots.sort_by(&:id)
      @d1.children = [@d2, @d3]
      assert_equal [@d1.id, @d4.id].sort, NamespacedDirectory.roots.map(&:id).sort
    end
    should "handle roots by property as symbol" do
      assert_equal @a.sort_by(&:id), NamespacedDirectory.roots.sort_by(&:id)
      @d1.children = [@d2, @d3]
      assert_equal [@d1.id], NamespacedDirectory.roots(:en).map(&:id)
      assert_equal [@d4.id], NamespacedDirectory.roots(:nl).map(&:id)
    end
    should "handle roots by property as string" do
      assert_equal @a.sort_by(&:id), NamespacedDirectory.roots.sort_by(&:id)
      @d1.children = [@d2, @d3]
      assert_equal [@d1.id], NamespacedDirectory.roots('en').map(&:id)
      assert_equal [@d4.id], NamespacedDirectory.roots('nl').map(&:id)
    end

    should "change by property to valid value when assigned as children" do
      assert_not_equal @d1.locale, @d3.locale
      @d1.children = [@d2, @d3]
      assert_equal @d1.locale, @d3.locale
      d3_reloaded = NamespacedDirectory.find(@d3.id)
      assert_equal @d1.locale, d3_reloaded.locale
    end

    should "change by property to valid value when assigned through add_child with save" do
      assert_not_equal @d1.locale, @d3.locale
      @d1.add_child(@d3).save
      assert_equal @d1.locale, @d3.locale
      d3_reloaded = NamespacedDirectory.find(@d3.id)
      assert_equal @d1.locale, d3_reloaded.locale
    end
    should "change by property to valid value when assigned through add_child without save" do
      assert_not_equal @d1.locale, @d3.locale
      @d1.add_child(@d3)
      assert_equal @d1.locale, @d3.locale
      d3_reloaded = NamespacedDirectory.find(@d3.id)
      assert_equal @d4.locale, d3_reloaded.locale
    end

    should "give a proper tree without namespace" do
      @d1.children = [@d2, @d3]
      full_tree = NamespacedDirectory.full_tree
      assert_equal [@d1.id, @d4.id].sort, full_tree.map(&:id).sort
      assert_equal [[@d2.id, @d3.id].sort, []].sort, full_tree.sort_by(&:id).map{|p| p.children.map(&:id).sort}.sort
    end
    should "give a proper tree with namespace as symbol" do
      @d1.children = [@d2, @d3]
      full_tree = NamespacedDirectory.full_tree(:en)
      assert_equal [@d1.id], full_tree.map(&:id)
      assert_equal [[@d2.id, @d3.id].sort], full_tree.map{|p| p.children.map(&:id).sort}
    end
    should "give a proper tree with namespace as string" do
      @d1.children = [@d2, @d3]
      full_tree = NamespacedDirectory.full_tree('en')
      assert_equal [@d1.id], full_tree.map(&:id)
      assert_equal [[@d2.id, @d3.id].sort], full_tree.map{|p| p.children.map(&:id).sort}
    end
    should "give a proper tree with namespace as property" do
      @d1.children = [@d2, @d3]
      full_tree = NamespacedDirectory.full_tree(:locale => 'en')
      assert_equal [@d1.id], full_tree.map(&:id)
      assert_equal [[@d2.id, @d3.id].sort], full_tree.map{|p| p.children.map(&:id).sort}
    end
    should "give a proper tree with revisions" do
      @d1.children = [@d2, @d3, @d4]
      full_tree = NamespacedDirectory.full_tree(:locale => 'en')
      assert_equal [@d1], full_tree
    end
  end
end
