require 'spec_helper'

describe "HasMany" do
  context "has_many" do
    context "with has_many" do
      it "create a fetch method for the associated objects" do
        user = User.new
        user.should respond_to :posts
      end

      it "raise an error if another property with the same name already exists" do
        expect {
          class ::DoubleHasManyUser
            include SimplyStored::Couch
            property :other_users
            has_many :other_users
          end
        }.to raise_error RuntimeError
      end

      it "fetch the associated objects" do
        user = User.create(:title => "Mr.")
        3.times {
          post = Post.new
          post.user = user
          post.save!
        }
        user.posts.size.should eq 3
      end

      it "set the parent object on the clients cache" do
        expect( User ).not_to receive(:find)
        user = User.create(:title => "Mr.")
        3.times {
          post = Post.new
          post.user = user
          post.save!
        }
        post = user.posts.first
        user.posts.first.user.should eq user
      end

      context "limit" do

        it "be able to limit the result set" do
          user = User.create(:title => "Mr.")
          3.times {
            post = Post.new
            post.user = user
            post.save!
          }
          user.posts(:limit => 2).size.should eq 2
        end

        it "use the given options in the cache-key" do
          user = User.create(:title => "Mr.")
          3.times {
            post = Post.new
            post.user = user
            post.save!
          }
          user.posts(:limit => 2).size.should eq 2
          user.posts(:limit => 3).size.should eq 3
        end

        it "be able to limit the result set - also for through objects" do
          @user = User.create(:title => "Mr.")
          first_pain = Pain.create
          frist_hemorrhoid = Hemorrhoid.create(:user => @user, :pain => first_pain)
          @user.pains.should eq [first_pain]
          second_pain = Pain.create
          second_hemorrhoid = Hemorrhoid.create(:user => @user, :pain => second_pain)
          @user.reload
          @user.pains.size.should eq 2
          @user.pains(:limit => 1).size.should eq 1
        end
      end

      context "order" do
        before do
          @user = User.create(:title => "Mr.")
          3.times {
            post = Post.new
            post.user = @user
            post.save!
          }
        end

        it "support different order" do
          expect{ @user.posts(:order => :asc) }.not_to raise_error
          expect { @user.posts(:order => :desc) }.not_to raise_error
        end

        it "reverse the order if :desc" do
          @user.posts(:order => :desc).map(&:id).should eq @user.posts(:order => :asc).map(&:id).reverse
        end

        it "work with the limit option" do
          last_post = Post.create(:user => @user)
          @user.posts(:order => :asc, :limit => 3).map(&:id).reverse.should_not eq @user.posts(:order => :desc, :limit => 3).map(&:id)
        end
      end

      it "verify the given options for the accessor method" do
        user = User.create(:title => "Mr.")
        expect { user.posts(:foo => false) }.to raise_error ArgumentError
      end

      it "verify the given options for the association defintion" do
        expect {
          User.instance_eval do
            has_many :foo, :bar => :do
          end
        }.to raise_error ArgumentError
      end

      it "only fetch objects of the correct type" do
        user = User.create(:title => "Mr.")
        post = Post.new
        post.user = user
        post.save!

        comment = Comment.new
        comment.user = user
        comment.save!

        user.posts.size.should eq 1
      end

      it "getter should user cache" do
        user = User.create(:title => "Mr.")
        post = Post.new
        post.user = user
        post.save!
        user.posts
        user.instance_variable_get("@posts")[:all].should eq [post]
      end

      it "add methods to handle associated objects" do
        user = User.new(:title => "Mr.")
        user.should respond_to :add_post
        user.should respond_to :remove_post
        user.should respond_to :remove_all_posts
      end

      it 'ignore the cache when requesting explicit reload' do
        user = User.create(:title => "Mr.")
        user.posts.should eq []
        post = Post.new
        post.user = user
        post.save!
        user.posts(:force_reload => true).should eq [post]
      end

      it "use the correct view when handling inheritance" do
        problem = Problem.create
        big_problem = BigProblem.create
        issue = Issue.create(:name => 'Thing', :problem => problem)
        problem.issues.size.should eq 1
        issue.update_attributes(:problem_id => nil, :big_problem_id => big_problem.id)
        big_problem.issues.size.should eq 1
      end

      context "when adding items" do
        it "add the item to the internal cache" do
          daddy = User.new(:title => "Mr.")
          item = Post.new
          daddy.posts.should eq []
          daddy.add_post(item)
          daddy.posts.should eq [item]
          daddy.instance_variable_get("@posts")[:all].should eq [item]
        end

        it "raise an error when the added item is not an object of the expected class" do
          user = User.new
          expect { user.add_post('foo') }.to raise_error(ArgumentError, "expected Post got String")
        end

        it "save the added item" do
          post = Post.new
          user = User.create(:title => "Mr.")
          user.add_post(post)
          post.should_not be_a_new_record
        end

        it 'set the forein key on the added object' do
          post = Post.new
          user = User.create(:title => "Mr.")
          user.add_post(post)
          post.user_id.should eq user.id
        end
      end

      context "when removing items" do
        it "should unset the foreign key" do
          user = User.create(:title => "Mr.")
          post = Post.create(:user => user)

          user.remove_post(post)
          post.user_id.should be nil
        end

        it "remove the item from the cache" do
          user = User.create(:title => "Mr.")
          post = Post.create(:user => user)
          user.posts.should include post
          user.remove_post(post)
          user.posts.any?{|p| post.id == p.id}.should_not be true
          user.instance_variable_get("@posts")[:all].should eq []
        end

        it "save the removed item with the nullified foreign key" do
          user = User.create(:title => "Mr.")
          post = Post.create(:user => user)

          user.remove_post(post)
          post = Post.find(post.id)
          post.user_id.should be nil
        end

        it 'raise an error when another object is the owner of the object to be removed' do
          user = User.create(:title => "Mr.")
          mrs = User.create(:title => "Mrs.")
          post = Post.create(:user => user)
          expect{ mrs.remove_post post }.to raise_error ArgumentError
        end

        it 'raise an error when the object is the wrong type' do
          user = User.new
          expect{ user.remove_post 'foo' }.to raise_error(ArgumentError, 'expected Post got String')
        end

        it "delete the object when dependent:destroy" do
          Category.instance_eval do
            has_many :tags, :dependent => :destroy
          end

          category = Category.create(:name => "food")
          tag = Tag.create(:name => "food", :category => category)
          tag.should_not be_new
          category.remove_tag(tag)

          Tag.find(:all).should eq []
        end

        it "not nullify or delete dependents if the options is set to :ignore when removing" do
          master = Master.create
          master_id = master.id
          servant = Servant.create(:master => master)
          master.remove_servant(servant)
          servant.reload.master_id.should eq master_id
        end

        it "not nullify or delete dependents if the options is set to :ignore when deleting" do
          master = Master.create
          master_id = master.id
          servant = Servant.create(:master => master)
          master.destroy
          servant.reload.master_id.should eq master_id
        end

      end

      context "when removing all items" do
        it 'nullify the foreign keys on all referenced items' do
          user = User.create(:title => "Mr.")
          post = Post.create(:user => user)
          post2 = Post.create(:user => user)
          user.remove_all_posts
          post = Post.find(post.id)
          post2 = Post.find(post2.id)
          post.user_id.should be nil
          post2.user_id.should be nil
        end

        it 'empty the cache' do
          user = User.create(:title => "Mr.")
          post = Post.create(:user => user)
          post2 = Post.create(:user => user)
          user.remove_all_posts
          user.posts.should eq []
          user.instance_variable_get("@posts")[:all].should eq []
        end

        context "when counting" do
          before do
            @user = User.create(:title => "Mr.")
          end

          it "define a count method" do
            @user.should respond_to :post_count
          end

          it "cache the result" do
            @user.post_count.should eq 0
            Post.create(:user => @user)
            @user.post_count.should eq 0
            @user.instance_variable_get("@post_count").should eq 0
            @user.instance_variable_set("@post_count", nil)
            @user.post_count.should eq 1
          end

          it "force reload even if cached" do
            @user.post_count.should eq 0
            Post.create(:user => @user)
            @user.post_count.should eq 0
            @user.post_count(:force_reload => true).should eq 1
          end

          it "count the number of belongs_to objects" do
            @user.post_count(:force_reload => true).should eq 0
            Post.create(:user => @user)
            @user.post_count(:force_reload => true).should eq 1
            Post.create(:user => @user)
            @user.post_count(:force_reload => true).should eq 2
          end

          it "not count foreign objects" do
            @user.post_count.should eq 0
            Post.create(:user => nil)
            Post.create(:user => User.create(:title => 'Doc'))
            @user.post_count.should eq 0
            Post.count.should eq 2
          end

          it "not count delete objects" do
            hemorrhoid = Hemorrhoid.create(:user => @user)
            @user.hemorrhoid_count.should eq 1
            hemorrhoid.delete
            @user.hemorrhoid_count(:force_reload => true).should eq 0
            @user.hemorrhoid_count(:force_reload => true, :with_deleted => true).should eq 1
          end

          it "work with has_many :through" do
            @user.pain_count.should eq 0
            first_pain = Pain.create
            frist_hemorrhoid = Hemorrhoid.create(:user => @user, :pain => first_pain)
            @user.pains.should eq [first_pain]
            @user.pain_count(:force_reload => true).should eq 1

            second_pain = Pain.create
            second_hemorrhoid = Hemorrhoid.create(:user => @user, :pain => second_pain)
            @user.pain_count(:force_reload => true).should eq 2
          end

        end
      end

      context 'when destroying the parent objects' do
        it "delete relations when dependent is destroy" do
          Category.instance_eval do
            has_many :tags, :dependent => :destroy
          end

          category = Category.create(:name => "food")
          tag = Tag.create(:name => "food", :category => category)

          Tag.find(:all).should eq [tag]
          category.destroy
          Tag.find(:all).should eq []
        end

        it "nullify relations when dependent is nullify" do

          user = User.create(:title => "Mr.")
          post = Post.create(:user => user)

          user.destroy
          post = Post.find(post.id)
          post.user_id.should be nil
        end

        it "nullify the foreign key even if validation forbids" do
          user = User.create(:title => "Mr.")
          post = StrictPost.create(:user => user)

          user.destroy
          post = StrictPost.find(post.id)
          post.user_id.should be nil
        end
      end
    end

    context "with has_many :trough" do
      before do
        @journal_1 = Journal.create
        @journal_2 = Journal.create
        @reader_1 = Reader.create
        @reader_2 = Reader.create
      end

      it "raise an exception if there is no :through relation" do

        expect {
          class FooHasManyThroughBar
            include SimplyStored::Couch
            has_many :foos, :through => :bars
          end
        }.to raise_error ArgumentError
      end

      it "define a getter" do
        @journal_1.should respond_to :readers
        @reader_1.should respond_to :journals
      end

      it "load the objects through" do
        membership = Membership.new
        membership.journal = @journal_1
        membership.reader = @reader_1
        membership.save.should be true

        membership.journal.should eq @journal_1
        membership.reader.should eq @reader_1
        @journal_1.reload.memberships.should eq [membership]
        @journal_1.reload.memberships.should eq [membership]

        @journal_1.readers.should eq [@reader_1]
        @reader_1.journals.should eq [@journal_1]

        membership_2 = Membership.new
        membership_2.journal = @journal_1
        membership_2.reader = @reader_2
        membership_2.save.should be true

        @journal_1.reload.readers.map(&:id).sort.should eq [@reader_1.id, @reader_2.id].sort
        @reader_1.reload.journals.map(&:id).sort.should eq [@journal_1.id]
        @reader_2.reload.journals.map(&:id).sort.should eq [@journal_1.id]

        membership_3 = Membership.new
        membership_3.journal = @journal_2
        membership_3.reader = @reader_2
        membership_3.save.should be true

        @journal_1.reload.readers.map(&:id).sort.should eq [@reader_1.id, @reader_2.id].sort
        @journal_2.reload.readers.map(&:id).sort.should eq [@reader_2.id].sort
        @reader_1.reload.journals.map(&:id).sort.should eq [@journal_1.id]
        @reader_2.reload.journals.map(&:id).sort.should eq [@journal_1.id, @journal_2.id].sort

        membership_3.destroy

        @journal_1.reload.readers.map(&:id).sort.should eq [@reader_1.id, @reader_2.id].sort
        @journal_2.reload.readers.should eq []
        @reader_1.reload.journals.map(&:id).sort.should eq [@journal_1.id]
        @reader_2.reload.journals.map(&:id).sort.should eq [@journal_1.id]
      end

      it "verify the given options" do
         expect{ @journal_1.readers(:foo => true) }.to raise_error ArgumentError
      end

      it "not try to destroy/nullify through-objects on parent object delete" do
        membership = Membership.new
        membership.journal = @journal_1
        membership.reader = @reader_1
        membership.save.should be true

        @reader_1.reload
        @journal_1.reload

        expect_any_instance_of( Journal ).not_to receive(:readers)
        expect_any_instance_of( Reader ).not_to receive("journal=")

        @journal_1.delete
      end
    end

    it "caches the parent relation" do
      existing_user = User.create title: "User"
      Post.create user: existing_user
      Post.create user: existing_user
      user = User.find(existing_user.id)
      expect{ user.posts.each.map(&:user) }.not_to exceed_query_limit 1
    end
  end
end
