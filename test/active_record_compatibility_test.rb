require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/fixtures/couch')

class PaginationTest < Test::Unit::TestCase
  context "primary_key" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
    end
    should "respond to primary_key and return id" do
      assert_equal 'id', Post.primary_key
    end
  end
end

class CallbackerTest < Test::Unit::TestCase

  context "run" do
    setup do
      CouchPotato::Config.database_name = 'simply_stored_test'
      recreate_db
    end

    should "raise_error on normal save" do
      assert_raise StandardError do
        Callbacker.new(name: 'Cally').save
      end
    end

    should "not raise error on save with false" do
      assert_nothing_raised do
        Callbacker.new(name: 'Cally').save(false)
      end
    end

    should "not raise error on save with validate: false" do
      assert_nothing_raised do
        Callbacker.new(name: 'Cally').save(validate: false)
      end
    end

    should "raise error on save with validate: true" do
      assert_raise StandardError do
        Callbacker.new(name: 'Cally').save(validate: true)
      end
    end
  end
end
