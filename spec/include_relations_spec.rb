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

  context '...' do
    it "includes has_many relations and sets the reverse relation on has many" do
      user1 = User.create title: "User1"
      user2 = User.create title: "User2"
      Post.create user: user1
      Post.create user: user1
      Post.create user: user2
      Post.create user: user2
      users = nil
      expect{ users = User.all.include_relation(:posts) }.not_to exceed_query_limit 2 # users.all and adding posts to both users
      expect{ users.map(&:posts).flatten.map(&:user) }.not_to perform_any_queries # reverse relation user must be set on each post
    end
  end
end
