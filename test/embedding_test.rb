require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')

class EmbeddingTest < Test::Unit::TestCase
  context "initialized comments" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
      @post = Post.new
      @post.embedded_comments= [{'ruby_class' => 'EmbeddedComment', 'body' => 'body1'}, {'ruby_class' => 'EmbeddedComment', 'body' => 'body2'}]
      @post.save
    end

    should "return a valid size" do
      assert_equal 2, @post.embedded_comments.size
      post_reloaded = Post.find(@post.id)
      assert_equal 2, post_reloaded.embedded_comments.size
    end

    should "delete comment using object" do
      @post.remove_embedded_comment(@post.embedded_comments.first)
      #debugger
      assert_equal 1, @post.embedded_comments.size
      post_reloaded = Post.find(@post.id)
      assert_equal 1, post_reloaded.embedded_comments.size
    end

    should "get all emmbedded using .all" do
      assert_equal 2, EmbeddedComment.all.size
    end

    should "get embedded object, not a hash" do
      assert_kind_of EmbeddedComment, EmbeddedComment.all.first
    end

    should "have a parent_object when loaded through all" do
      assert_equal @post, EmbeddedComment.all.first.parent_object
    end

    should "save an instance" do
      comment = @post.embedded_comments.first
      comment.body = 'body-changed'
      comment.save
      comment_reloaded = Post.find(@post.id).embedded_comments.first
      assert_equal 'body-changed', comment_reloaded.body
    end

    should "delete comment using integer" do

    end
    should "delete comment using integer string" do

    end
  end
end
