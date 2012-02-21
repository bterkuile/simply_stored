require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')
require 'simply_stored/include_relation'

class IncludeRelationsTest < Test::Unit::TestCase
  context "initialized posts" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
      @user = User.create :title => 'Include relation posts user'
      @post1 = Post.create(:user => @user)
      @post2 = Post.create(:user => @user)
      @user.reload
      @post1 = Post.find(@post1.id)
      @post2 = Post.find(@post2.id)
    end

    should "have proper relations without include_relation" do
      assert_equal [@post1, @post2].sort_by(&:id), @user.posts.sort_by(&:id)
    end
    should "have proper relations with include_relation" do
      [@user].include_relation(:posts)
      assert_equal [@post1, @post2].sort_by(&:id), @user.posts.sort_by(&:id)
    end
    should "have proper relations with include_relation called twice" do
      [@user].include_relation(:posts)
      [@user].include_relation(:posts)
      assert_equal [@post1, @post2].sort_by(&:id), @user.posts.sort_by(&:id)
    end
  end
end
