require 'spec_helper'
describe "Include relation, aggregate many queries to one simplified one for performance" do
  context "initialized posts" do
    before do
      @user = User.create :title => 'Include relation posts user'
      @post1 = Post.create(:user => @user)
      @post2 = Post.create(:user => @user)
      @user.reload
      @post1 = Post.find(@post1.id)
      @post2 = Post.find(@post2.id)
    end

    it "have proper relations without include_relation" do
      @user.posts.should match_array [@post1, @post2]
    end

    it "have proper relations with include_relation" do
      [@user].include_relation(:posts)
      #assert_equal [@post1, @post2].sort_by(&:id), @user.posts.sort_by(&:id)
      @user.posts.should match_array [@post1, @post2]
    end

    it "have proper relations with include_relation called twice" do
      [@user].include_relation(:posts)
      [@user].include_relation(:posts)
      @user.posts.should match_array [@post1, @post2]
    end
  end
end
