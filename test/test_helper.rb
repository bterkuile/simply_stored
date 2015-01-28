require 'rubygems'
#require 'minitest'
require "minitest/autorun"
require "minitest-spec-context"
require 'bundler/setup'
require 'active_support/testing/assertions'
require 'shoulda'
require 'test/unit'
require 'pry'
require 'mocha/setup'
$:.unshift(File.expand_path(File.dirname(__FILE__) + "/../lib"))
puts File.expand_path(File.dirname(__FILE__) + "/lib")
require 'simply_stored'
class MiniTest::Unit::TestCase
  include ActiveSupport::Testing::Assertions

  def recreate_db
    CouchPotato.couchrest_database.delete! rescue nil
    CouchPotato.couchrest_database.server.create_db CouchPotato::Config.database_name
  end

end
