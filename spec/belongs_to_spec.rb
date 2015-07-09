require 'spec_helper'

describe "BelongsTo" do
  context "with associations" do
    context "with belongs_to" do
      it "generate a view for the association" do
        #Post.respond_to?(:association_post_belongs_to_user).should be_present
        Post.should respond_to :association_post_belongs_to_user
      end

      it "raise an error if another property with the same name already exists" do
        expect {
          class ::DoubleBelongsToUser
            include SimplyStored::Couch
            property :user
            belongs_to :user
          end
        }.to raise_error RuntimeError
      end

      it "add the foreign key id to the referencing object" do
        user = User.create(:title => "Mr.")
        post = Post.create(:user => user)

        post = Post.find(post.id)
        post.user_id.should eq user.id
      end

      it "create a property for the foreign key attribute" do
        Post.properties.any?{|p| p.is_a?(CouchPotato::Persistence::SimpleProperty) && p.name.to_s == 'user_id'}.should be true
      end

      it "notice a change to the foreign key attribute in dirty checks" do
        user = User.create!(:title => 'Prof')
        post = Post.create!
        post.user = user
        post.should be_user_id_changed
      end

      it "set also the foreign key id to nil if setting the referencing object to nil" do
        user = User.create(:title => "Mr.")
        post = Post.create(:user => user)
        post.user = nil
        post.save!
        post.reload.user.should be nil
        post.reload.user_id.should be nil
      end

      it "fetch the object from the database when requested through the getter" do
        user = User.create(:title => "Mr.")
        post = Post.create(:user => user)

        post = Post.find(post.id)
        post.user.should eq user
      end

      it "mark the referencing object as dirty" do
        user = User.create(:title => "Mr.")
        post = Post.create
        post.user = user
        post.should be_dirty
      end

      it "allow assigning a different object and store the id accordingly" do
        user = User.create(:title => "Mr.")
        user2 = User.create(:title => "Mrs.")
        post = Post.create(:user => user)
        post.user = user2
        post.save

        post = Post.find(post.id)
        post.user.id.should eq user2.id
      end

      it "check the class and raise an error if not matching in belongs_to setter" do
        post = Post.create
        expect{ post.user = 'foo' }.to raise_error(ArgumentError, 'expected User got String')
      end

      it 'not query for the object twice in getter' do
        user = User.create(:title => "Mr.")
        post = Post.create(:user => user)
        post = Post.find(post.id)
        expect( User ).to receive(:find).and_return "user"
        post.user
        expect( User ).not_to receive(:find)
        post.user
      end

      it 'use cache in getter' do
        post = Post.create
        post.instance_variable_set("@user", 'foo')
        post.user.should eq 'foo'
      end

      it "ignore the cache if force_reload is given as an option" do
        user = User.create(:name => 'Dude', :title => 'Mr.')
        post = Post.create(:user => user)
        post.reload
        post.instance_variable_set("@user", 'foo')
        post.user(:force_reload => true).should_not eq 'foo'
      end

      it 'set cache in setter' do
        post = Post.create
        user = User.create :title => 'Mr.'
        post.instance_variable_get("@user").should be nil
        post.user = user
        post.instance_variable_get("@user").should eq user
      end

      it "not hit the database when the id column is empty" do
        expect( User ).not_to receive(:find)
        post = Post.create
        post.user
      end

      it "know when the associated object changed" do
        post = Post.create(:user => User.create(:title => "Mr."))
        user2 = User.create(:title => "Mr.")
        post.user = user2
        post.should be_user_id_changed
      end

      it "not be changed when an association has not changed" do
        post = Post.create(:user => User.create(:title => "Mr."))
        post.should_not be_user_id_changed
      end

      it "not be changed when assigned the same object" do
        user = User.create(:title => "Mr.")
        post = Post.create(:user => user)
        post.user = user
        post.should_not be_user_changed
      end

      it "not be changed after saving" do
        user = User.create(:title => "Mr.")
        post = Post.new
        post.user = user
        post.should be_user_id_changed
        post.save!
        post.should_not be_user_id_changed
      end

      it "have a proper _was value" do
        user = User.create(:title => "Mr.")
        user2 = User.create(:title => "Mrs.")
        post = Post.new

        post.save
        post.user.should be nil
        post.user_id.should be nil

        post.user = user
        #post.user_was.should be nil
        post.user_id_was.should be nil

        post.save

        post.user = user2
        #post.user_was.should eq user
        post.user_id_was.should eq user.id
      end

      it "set the parent object on has_many association" do
        # Copy from has_many, but belongs here as well
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

      it "set the parent object on has_one association" do
        # Taken from has_one, but belongs here as well
        expect( Instance ).not_to receive(:find)
        instance = Instance.create
        identity = Identity.create(:instance => instance)

        instance.identity.instance.should eq instance
      end

      it "handle a foreign_key of '' as nil" do
        post = Post.create
        post.user_id = ''

        post.user.should be nil
      end

      context "with aliased associations" do
        it "allow different names for the same class" do
          editor = User.create(:name => 'Editor', :title => 'Dr.')
          author = User.create(:name => 'author', :title => 'Dr.')
          editor.id.should_not be nil
          author.id.should_not be nil

          doc = Document.create(:editor => editor, :author => author)
          doc.save!
          doc.editor_id.should eq editor.id
          doc.author_id.should eq author.id
          doc = Document.find(doc.id)
          doc.editor.should_not be nil
          doc.author.should_not be nil
          doc.editor.id.should eq editor.id
          doc.author.id.should eq author.id
        end
      end
    end
  end


end
