require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')

class PaginationTest < Test::Unit::TestCase
  context "pagination" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
    end
    should "not raise error when page and per_page are specified" do
      assert_nothing_raised do
        User.all(:page => 1, :per_page => 2)
      end
    end

    should "respond to pagination methods" do
      paginated = User.all(:page => 1, :per_page => 2 )
      assert_equal 1, paginated.current_page
      assert_equal 1, paginated.num_pages
      assert_equal 2, paginated.per_page
    end

    should "respond to modified pagination methods" do
      paginated = Comment.all(:page => 1, :per_page => 2 )
      assert_equal 1, paginated.current_page_modified
      assert_equal 1, paginated.num_pages_modified
      assert_equal 2, paginated.per_page_modified
    end

    should "display individual objects on pages with per_page is one" do
      u1 = User.create(:title => 'user1', :created_at => Time.now )
      u2 = User.create(:title => 'user2', :created_at => Time.now + 5.minutes )
      u3 = User.create(:title => 'user3', :created_at => Time.now + 10.minutes )
      assert_equal [u1, u2, u3], User.all # normal behaviour
      assert_equal u1, User.all(:per_page => 1).first # default to page 1
      assert_equal u2, User.all(:page => 2, :per_page => 1).first
      assert_equal u3, User.all(:page => 3, :per_page => 1).first
    end
  end
end
