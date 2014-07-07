require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')

describe "Attribute accessing" do
  before do
    CouchPotato::Config.database_name = 'simply_stored_test'
    recreate_db
  end

  context "with brackets" do
    it "access with string argument" do
      user = User.new
      user.name = 'UTest'
      assert_equal 'UTest', user['name']
    end
    it "access with symbol argument" do
      user = User.new
      user.name = 'UTest'
      assert_equal 'UTest', user[:name]
    end
  end
end
