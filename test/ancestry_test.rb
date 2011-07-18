require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')

class AncestryTest < Test::Unit::TestCase
  context "with hierarchy" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
      @d1 = Directory.create(:name => 'dir1')
      @d2 = Directory.create(:name => 'dir2')
      @d3 = Directory.create(:name => 'dir3')
      @d4 = Directory.create(:name => 'dir4')
      @a = [@d1, @d2, @d3, @d4]
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
  end
end
