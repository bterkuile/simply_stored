require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')

class PaginationTest < Test::Unit::TestCase
  context "primary_key" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
    end
    should "respond to primary_key and return id" do
      assert_equal 'id', Post.primary_key
    end
  end
end
