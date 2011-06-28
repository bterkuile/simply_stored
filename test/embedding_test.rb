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
      debugger
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

  context "Creation of comment" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
      @post = Post.new
      @post.save
    end

    should "not save when no parent is present" do
      comment = EmbeddedComment.new :body => 'no parent'
      assert_equal false, comment.save
      puts comment.errors.full_messages.inspect
    end

    should "save when initialized with parent actual name initialization" do
      comment = EmbeddedComment.new :body => 'no parent', :post => @post
      assert comment.save
      assert comment.post = @post
      assert comment.parent_object = @post
      assert @post.embedded_comments.include?(comment)
      reloaded_post = Post.find @post.id
      assert reloaded_post.embedded_comments.include?(comment)
    end
    should "save when initialized with parent object initialization" do
      comment = EmbeddedComment.new :body => 'no parent', :parent_object => @post
      assert comment.save
      assert comment.post = @post
      assert comment.parent_object = @post
      assert @post.embedded_comments.include?(comment)
      reloaded_post = Post.find @post.id
      assert reloaded_post.embedded_comments.include?(comment)
    end
    should "save when parent object is assigned later with relation name" do
      comment = EmbeddedComment.new :body => 'no parent'
      comment.post = @post
      assert comment.save
      assert comment.post = @post
      assert comment.parent_object = @post
      assert @post.embedded_comments.include?(comment)
      reloaded_post = Post.find @post.id
      assert reloaded_post.embedded_comments.include?(comment)
    end
    should "save when parent object is assigned later with parent object assignment" do
      comment = EmbeddedComment.new :body => 'no parent'
      comment.parent_object = @post
      assert comment.save
      assert comment.post = @post
      assert comment.parent_object = @post
      assert @post.embedded_comments.include?(comment)
      reloaded_post = Post.find @post.id
      assert reloaded_post.embedded_comments.include?(comment)
    end
  end

  context "belongs to stric_post" do
    setup do
      @strict_post = StrictPost.create
      @post = Post.new
      @post.embedded_comments= [{'ruby_class' => 'EmbeddedComment', 'body' => 'body1'}, {'ruby_class' => 'EmbeddedComment', 'body' => 'body2'}]
      @post.save
    end

    should "add embedded comments to strict_post" do
      @strict_post.embedded_comments = @post.embedded_comments
      assert @strict_post.save
    end

  end
end
