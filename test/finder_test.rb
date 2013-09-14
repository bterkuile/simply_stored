require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')

class FinderTest < Test::Unit::TestCase
  context "when finding instances" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
    end

    context "with find(:all)" do
      setup do
        User.create(:title => "Mr.")
        User.create(:title => "Mrs.")
      end

      should "return all instances" do
        assert_equal 2, User.find(:all).size
      end

      should "allow a limit" do
        assert_equal 1, User.find(:all, :limit => 1).size
      end

      should "allow to order the results" do
        assert_not_equal User.find(:all).map(&:id), User.find(:all, :order => :desc).map(&:id)
        assert_equal User.find(:all).map(&:id).reverse, User.find(:all, :order => :desc).map(&:id)
      end
    end

    context "to find all instances" do
      should 'generate a default find_all view' do
        assert User.respond_to?(:all_documents)
      end

      should 'return all the users when calling all' do
        User.create(:title => "Mr.")
        User.create(:title => "Mrs.")
        assert_equal 2, User.all.size
      end
    end

    context "to find one instance" do
      should 'return one user when calling first' do
        user = User.create(:title => "Mr.")
        assert_equal user, User.first
      end

      should 'understand the order' do
        assert_nothing_raised do
          User.first(:order => :desc)
        end
      end

      should 'find the last as a reverse first' do
        User.expects(:find).with(:first, :order => :desc)
        User.last
      end

      should 'return nil when no user found' do
        assert_nil User.first
      end
    end

    context "when finding with just an identifier" do
      should "find just one instance" do
        user = User.create(:title => "Mr.")
        assert User.find(user.id).kind_of?(User)
      end

      should 'raise an error when no record was found' do
        assert_raises(SimplyStored::RecordNotFound) do
          User.find('abc')
        end
      end

      should 'tell you which class failed to load something' do
        exception = nil
        begin
          User.find('abc')
        rescue SimplyStored::RecordNotFound => e
          exception = e
        end
        assert_equal "User could not be found with \"abc\"", exception.message
      end

      should 'raise an error when nil was specified' do
        assert_raises(SimplyStored::Error) do
          User.find(nil)
        end
      end

      should 'raise an error when the record was not of the expected type' do
        post = Post.create
        assert_raises(SimplyStored::RecordNotFound) do
          User.find(post.id)
        end
      end
    end

    context "with a find_by prefix" do
      setup do
        recreate_db
      end

      should "create a view for the called finder" do
        User.find_by_name("joe")
        assert User.respond_to?(:by_name)
      end

      should 'not create the view when it already exists' do
        User.expects(:view).never
        User.find_by_name_and_created_at("joe", 'foo')
      end

      should "create a method to prevent future loops through method_missing" do
        assert !User.respond_to?(:find_by_title)
        User.find_by_title("Mr.")
        assert User.respond_to?(:find_by_title)
      end

      should "call the generated view and return the result" do
        user = User.create(:homepage => "http://www.peritor.com", :title => "Mr.")
        assert_equal user, User.find_by_homepage("http://www.peritor.com")
      end

      should 'find only one instance when using find_by' do
        User.create(:title => "Mr.")
        assert User.find_by_title("Mr.").is_a?(User)
      end

      should "find a record through an association" do
        user = User.create(:title => "Mr.")
        post = Post.create user: user
        assert_equal post, Post.find_by_user(user)
      end

      should "find a record through an association that raises when not found" do
        user = User.create(:title => "Mr.")
        post = Post.create user: user
        assert_equal post, Post.find_by_user!(user)
      end

      should "raise an error if the parameters don't match" do
        assert_raise(ArgumentError) do
          User.find_by_title()
        end

        assert_raise(ArgumentError) do
          User.find_by_title(1,2,3,4,5)
        end
      end

      should "return nil when no result is found" do
        assert_nil User.find_by_title("Mr.")
      end

      should "return nil for multiple finders when no result is found" do
        assert_nil User.find_by_title_and_homepage("Mr.", "http://www.companytools.nl/")
      end

      should "find a record when it ends with an exclamation mark!" do
        User.create(:title => "Mr.")
        assert User.find_by_title!("Mr.").is_a?(User)
      end

      should "return raise a not found exception when called using an exclamation mark! and is no record is found" do
        assert_raise(SimplyStored::RecordNotFound) do
          User.find_by_title!("Mr.")
        end
      end

      should "find a record using multiple arguments when it ends with an exclamation mark!" do
        User.create(:title => "Mr.", :homepage => "http://www.companytools.nl/")
        assert User.find_by_title_and_homepage!("Mr.", "http://www.companytools.nl/").is_a?(User)
      end

      should "return raise a not found exception when called using an exclamation mark! and no record is found" do
        assert_raise(SimplyStored::RecordNotFound) do
          User.find_by_title_and_homepage!("Mr.", "http://www.companytools.nl/")
        end
      end
    end

    context "with a find_all_by prefix" do
      should "create a view for the called finder" do
        User.find_all_by_name("joe")
        assert User.respond_to?(:by_name)
      end

      should 'not create the view when it already exists' do
        User.expects(:view).never
        User.find_all_by_name_and_created_at("joe", "foo")
      end

      should "create a method to prevent future loops through method_missing" do
        assert !User.respond_to?(:find_all_by_foo_attribute)
        User.find_all_by_foo_attribute("Mr.")
        assert User.respond_to?(:find_all_by_foo_attribute)
      end

      should "call the generated view and return the result" do
        user = User.create(:homepage => "http://www.peritor.com", :title => "Mr.")
        assert_equal [user], User.find_all_by_homepage("http://www.peritor.com")
      end

      should "return an emtpy array if none found" do
        recreate_db
        assert_equal [], User.find_all_by_title('Mr. Magoooo')
      end

      should 'find all instances when using find_all_by' do
        User.create(:title => "Mr.")
        User.create(:title => "Mr.")
        assert_equal 2, User.find_all_by_title("Mr.").size
      end

      should "find all instances when specifying keys" do
        User.create :name => 'john', :title => 'Mr.'
        User.create :name => 'doe', :title => 'Mr.'
        assert_equal ['doe', 'john'], User.find_all_by_name(:keys => ['john', 'doe', 'jane']).map{|u| u.name}.sort
      end

      should "raise an error if the parameters don't match" do
        assert_raise(ArgumentError) do
          User.find_all_by_title()
        end

        assert_raise(ArgumentError) do
          User.find_all_by_title(1,2,3,4,5)
        end
      end

      should "return an empty array when no result is found" do
        assert_empty User.find_all_by_title("Mr.")
      end

      should "return an empty array  for multiple finders when no result is found" do
        assert_empty User.find_all_by_title_and_homepage("Mr.", "http://www.companytools.nl/")
      end

      should "find records when the finder ends with an exclamation mark!" do
        u1 = User.create(:name => 'john', :title => "Mr.")
        u2 = User.create(:name => 'doe',  :title => "Mr.")
        assert_equal %w[doe john], User.find_all_by_title!("Mr.").map(&:name).sort
      end

      should "return raise a not found exception when called using an exclamation mark! and is no records are found" do
        assert_raise(SimplyStored::RecordNotFound) do
          User.find_all_by_title!("Mr.")
        end
      end

      should "find records using multiple arguments when the finder ends with an exclamation mark!" do
        User.create(:name => 'john', :title => "Mr.", :homepage => "http://www.companytools.nl/")
        User.create(:name => 'doe',  :title => "Mr.", :homepage => "http://www.companytools.nl/")
        User.create(:name => 'juan', :title => "Mr.", :homepage => "http://www.peritor.com/")
        assert_equal %w[doe john], User.find_all_by_title_and_homepage!("Mr.", "http://www.companytools.nl/").map(&:name).sort
      end

      should "return raise a not found exception when the finder ends with an exclamation mark! and no records are found" do
        assert_raise(SimplyStored::RecordNotFound) do
          User.find_all_by_title_and_homepage!("Mr.", "http://www.companytools.nl/")
        end
      end
      should "find all records through an association" do
        user1 = User.create(:title => "Mr.")
        user2 = User.create(:title => "Mrs.")
        post1 = Post.create user: user1
        post2 = Post.create user: user1
        post3 = Post.create user: user2
        assert_equal [post1, post2].sort_by(&:id), Post.find_all_by_user(user1).sort_by(&:id)
      end

      should "find all records through an association that raises when not found" do
        user1 = User.create(:title => "Mr.")
        user2 = User.create(:title => "Mrs.")
        post1 = Post.create user: user1
        post2 = Post.create user: user1
        post3 = Post.create user: user2
        assert_equal [post1, post2].sort_by(&:id), Post.find_all_by_user!(user1).sort_by(&:id)
      end
    end
  end

end
