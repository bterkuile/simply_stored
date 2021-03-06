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

    should "change attribute when not loaded through parent object" do
      embedded_comments = EmbeddedComment.all
      embedded_comment = embedded_comments.first
      embedded_comment.body = 'newbody'
      embedded_comment.save
      embedded_comments_reloaded = EmbeddedComment.all
      assert embedded_comments_reloaded.map(&:body).include?('newbody')
    end

    should "change attribute when not loaded through parent object" do
      # Same as above, but now save through parent object
      embedded_comments = EmbeddedComment.all
      embedded_comment = embedded_comments.first
      embedded_comment.body = 'newbody'
      embedded_comment.parent_object.is_dirty
      embedded_comment.parent_object.save
      embedded_comments_reloaded = EmbeddedComment.all
      assert embedded_comments_reloaded.map(&:body).include?('newbody')
    end

    should "delete comment using integer" do

    end
    should "delete comment using integer string" do

    end

    should "Count" do
      assert_equal 2, EmbeddedComment.count
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
      assert comment.errors[:post].include?('no_parent')
    end

    should "save when initialized with parent actual name initialization" do
      comment = EmbeddedComment.new :body => 'no parent', :post => @post
      assert comment.save
      assert_equal @post, comment.post
      assert_equal @post, comment.parent_object
      assert @post.embedded_comments.include?(comment)
      reloaded_post = Post.find @post.id
      assert reloaded_post.embedded_comments.include?(comment)
    end
    should "save when initialized with parent object initialization" do
      comment = EmbeddedComment.new :body => 'no parent', :parent_object => @post
      assert comment.save
      assert_equal comment.post, @post
      assert_equal comment.parent_object, @post
      assert @post.embedded_comments.include?(comment)
      assert comment.save
      reloaded_post = Post.find @post.id
      assert reloaded_post.embedded_comments.include?(comment)
    end
    should "save when parent object is assigned later with relation name" do
      comment = EmbeddedComment.new :body => 'no parent'
      comment.post = @post
      assert comment.save
      assert_equal comment.post, @post
      assert_equal comment.parent_object, @post
      assert @post.embedded_comments.include?(comment)
      reloaded_post = Post.find @post.id
      assert reloaded_post.embedded_comments.include?(comment)
    end
    should "save when parent object is assigned later with parent object assignment" do
      comment = EmbeddedComment.new :body => 'no parent'
      comment.parent_object = @post
      assert comment.save
      assert_equal comment.post, @post
      assert_equal comment.parent_object, @post
      assert @post.embedded_comments.include?(comment)
      reloaded_post = Post.find @post.id
      assert reloaded_post.embedded_comments.include?(comment)
    end
  end

  context "belongs to stric_post" do
    setup do
      recreate_db
      @user = User.create(:name => 'embedding user')
      @strict_post = StrictPost.create(:user => @user)
      @post = Post.new
      @post.embedded_comments= [{'ruby_class' => 'EmbeddedComment', 'body' => 'body1'}, {'ruby_class' => 'EmbeddedComment', 'body' => 'body2'}]
      @post.save
    end

    should "add embedded comments to strict_post" do
      # @strict_post.embedded_comments = @post.embedded_comments I should have my own test
      assert @strict_post.save
      @post.embedded_comments.each{|ec| ec.strict_post = @strict_post; ec.save}
      strict_post_reloaded = StrictPost.find(@strict_post.id)
      assert_equal strict_post_reloaded.embedded_comments.size, @post.embedded_comments.size
    end

    should "have strict_post as association" do

      # @strict_post.embedded_comments = @post.embedded_comments I should have my own test
      assert @strict_post.save
      @post.embedded_comments.each{|ec| ec.strict_post = @strict_post; ec.save}
      post_reloaded = Post.find(@post.id)
      comment_reloaded = post_reloaded.embedded_comments.first
      assert_equal comment_reloaded.strict_post, @strict_post
    end

    should "have parent object when queried through relation" do
      assert @strict_post.save
      @post.embedded_comments.each{|ec| ec.strict_post = @strict_post; ec.save}
      strict_post_reloaded = StrictPost.find(@strict_post.id)
      assert_equal strict_post_reloaded.embedded_comments.first, @post.embedded_comments.first
      assert_equal strict_post_reloaded.embedded_comments.first.post, @post
    end

    should "have actual object same as in parent object" do
      assert @strict_post.save
      @post.embedded_comments.each{|ec| ec.strict_post = @strict_post; ec.save}
      strict_post_reloaded = StrictPost.find(@strict_post.id)
      embedded_comment = strict_post_reloaded.embedded_comments.first
      assert embedded_comment.parent_object.embedded_comments.map(&:object_id).include?(embedded_comment.object_id)
    end
  end
end
