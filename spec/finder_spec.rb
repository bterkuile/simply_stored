require 'spec_helper'


describe "Finder" do
  context "when finding instances" do
    context "with find(:all)" do
      before do
        User.create(title: "Mr.")
        User.create(title: "Mrs.")
      end

      it "return all instances" do
        User.find(:all).size.should eq 2
      end

      it "allow a limit" do
        User.find(:all, limit: 1).size.should eq 1
      end

      it "allow to order the results" do
        User.find(:all, order: :desc).map(&:id).should_not eq User.find(:all).map(&:id)
        User.find(:all, order: :desc).map(&:id).should eq User.find(:all).map(&:id).reverse
      end
    end

    context "to find all instances" do
      it 'generate a default find_all view' do
        User.should respond_to :all_documents
      end

      it 'return all the users when calling all' do
        User.create(title: "Mr.")
        User.create(title: "Mrs.")
        User.all.size.should eq 2
      end
    end

    context "to find one instance" do
      it 'return one user when calling first' do
        user = User.create(title: "Mr.")
        User.first.should eq user
      end

      it 'understand the order' do
        expect{ User.first(order: :desc) }.not_to raise_error
      end

      it 'find the last as a reverse first' do
        expect( User ).to receive(:find).with(:first, order: :desc)
        User.last
      end

      it 'return nil when no user found' do
        User.first.should be nil
      end
    end

    context "when finding with just an identifier" do
      it "find just one instance" do
        user = User.create(title: "Mr.")
        User.find(user.id).should be_kind_of User
      end

      it 'raise an error when no record was found and tell you which class failed to load something' do
        expect{ User.find 'abc' }.to raise_error SimplyStored::RecordNotFound, "User could not be found with \"abc\""
      end

      it 'raise an error when nil was specified' do
        expect{ User.find(nil) }.to raise_error SimplyStored::Error
      end

      it 'raise an error when the record was not of the expected type' do
        post = Post.create
        expect{ User.find(post.id) }.to raise_error SimplyStored::RecordNotFound
      end
    end

    context "with a find_by prefix" do
      it "create a view for the called finder" do
        User.find_by_name("joe")
        User.should respond_to :by_name
      end

      it 'not create the view when it already exists' do
        expect( User ).not_to receive :view
        User.find_by_name_and_created_at("joe", 'foo')
      end

      it "create a method to prevent future loops through method_missing" do
        User.should_not respond_to :find_by_title
        User.find_by_title("Mr.")
        User.should respond_to :find_by_title
      end

      it "call the generated view and return the result" do
        user = User.create(homepage: "http://www.peritor.com", title: "Mr.")
        User.find_by_homepage("http://www.peritor.com").should eq user
      end

      it 'find only one instance when using find_by' do
        User.create(title: "Mr.")
        User.find_by_title("Mr.").should be_a User
      end

      it "find a record through an association" do
        user = User.create(title: "Mr.")
        post = Post.create user: user
        Post.find_by_user(user).should eq post
      end

      it "find a record through an association that raises when not found" do
        user = User.create(title: "Mr.")
        post = Post.create user: user
        Post.find_by_user!(user).should eq post
      end

      it "raise an error if the parameters don't match" do
        expect{ User.find_by_title() }.to raise_error ArgumentError
        expect{ User.find_by_title(1,2,3,4,5) }.to raise_error ArgumentError
      end

      it "return nil when no result is found" do
        User.find_by_title("Mr.").should be nil
      end

      it "return nil for multiple finders when no result is found" do
        User.find_by_title_and_homepage("Mr.", "http://www.companytools.nl/").should be nil
      end

      it "find a record when it ends with an exclamation mark!" do
        User.create(title: "Mr.")
        User.find_by_title!("Mr.").should be_a User
      end

      it "return raise a not found exception when called using an exclamation mark! and is no record is found" do
        expect{ User.find_by_title!("Mr.") }.to raise_error SimplyStored::RecordNotFound
      end

      it "find a record using multiple arguments when it ends with an exclamation mark!" do
        User.create(title: "Mr.", homepage: "http://www.companytools.nl/")
        User.find_by_title_and_homepage!("Mr.", "http://www.companytools.nl/").should be_a User
      end

      it "return raise a not found exception when called using an exclamation mark! and no record is found" do
        expect{ User.find_by_title_and_homepage!("Mr.", "http://www.companytools.nl/") }.to raise_error SimplyStored::RecordNotFound
      end
    end

    context "with a find_all_by prefix" do
      it "create a view for the called finder" do
        User.find_all_by_name("joe")
        User.should respond_to :by_name
      end

      it 'not create the view when it already exists' do
        expect( User ).not_to receive(:view)
        User.find_all_by_name_and_created_at("joe", "foo")
      end

      it "create a method to prevent future loops through method_missing" do
        User.should_not respond_to :find_all_by_foo_attribute
        User.find_all_by_foo_attribute("Mr.")
        User.should respond_to :find_all_by_foo_attribute
      end

      it "call the generated view and return the result" do
        user = User.create(homepage: "http://www.peritor.com", title: "Mr.")
        User.find_all_by_homepage("http://www.peritor.com").should eq [user]
      end

      it "return an emtpy array if none found" do
        User.find_all_by_title('Mr. Magoooo').should be_empty
      end

      it 'find all instances when using find_all_by' do
        User.create(title: "Mr.")
        User.create(title: "Mr.")
        User.find_all_by_title("Mr.").size.should eq 2
      end

      it "find all instances when specifying keys" do
        User.create name: 'john', title: 'Mr.'
        User.create name: 'doe', title: 'Mr.'
        User.find_all_by_name(keys: ['john', 'doe', 'jane']).map(&:name).should match_array %w[doe john]
      end

      it "raise an error if the parameters don't match" do
        expect{ User.find_all_by_title() }.to raise_error ArgumentError
        expect{ User.find_all_by_title(1,2,3,4,5) }.to raise_error ArgumentError
      end

      it "return an empty array  for multiple finders when no result is found" do
        User.find_all_by_title_and_homepage("Mr.", "http://www.companytools.nl/").should be_empty
      end

      it "find records when the finder ends with an exclamation mark!" do
        u1 = User.create(name: 'john', title: "Mr.")
        u2 = User.create(name: 'doe',  title: "Mr.")
        User.find_all_by_title!("Mr.").map(&:name).should match_array %w[doe john]
      end

      it "return raise a not found exception when called using an exclamation mark! and is no records are found" do
        expect{ User.find_all_by_title!("Mr.") }.to raise_error SimplyStored::RecordNotFound
      end

      it "find records using multiple arguments when the finder ends with an exclamation mark!" do
        User.create(name: 'john', title: "Mr.", homepage: "http://www.companytools.nl/")
        User.create(name: 'doe',  title: "Mr.", homepage: "http://www.companytools.nl/")
        User.create(name: 'juan', title: "Mr.", homepage: "http://www.peritor.com/")
        User.find_all_by_title_and_homepage!("Mr.", "http://www.companytools.nl/").map(&:name).should match_array %w[doe john]
      end

      it "return raise a not found exception when the finder ends with an exclamation mark! and no records are found" do
        expect { User.find_all_by_title_and_homepage!("Mr.", "http://www.companytools.nl/") }.to raise_error SimplyStored::RecordNotFound
      end
      it "find all records through an association" do
        user1 = User.create(title: "Mr.")
        user2 = User.create(title: "Mrs.")
        post1 = Post.create user: user1
        post2 = Post.create user: user1
        post3 = Post.create user: user2
        Post.find_all_by_user(user1).should match_array [post1, post2]
      end

      it "find all records through an association that raises when not found" do
        user1 = User.create(title: "Mr.")
        user2 = User.create(title: "Mrs.")
        post1 = Post.create user: user1
        post2 = Post.create user: user1
        post3 = Post.create user: user2
        Post.find_all_by_user!(user1).should match_array [post1, post2]
      end
    end
  end

end
