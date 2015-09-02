require 'pry'
require 'simply_stored'
require 'fixtures/couch'

Dir.glob("spec/support/**/*.rb").each {|f| require f.sub(/^spec\//, '')}
# VIM TRICKS
# :s/assert_equal \([^,]\+\), \(.*\)/expect( \2 ).to eq \1  
# :s/assert_equal \[\([^\]]\+\)\], \(.*\)/expect( \2 ).to eq [\1]
$performed_queries = []
CouchRest.class_eval do
  class << self
    alias_method :old_get, :get
    def get(uri, options={})
      $performed_queries << {url: uri, options: options} if is_query_uri?(uri)
      old_get(uri, options)
    end

    def is_query_uri?(uri)
      return false if uri =~ /\/_design\/\w+$/ # request design doc
      return false if uri =~ /\/_uuids/
      true
    end
  end
end
RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = [:expect, :should] }
  config.color = true
  config.tty = true

  config.before :suite do
    CouchPotato::Config.database_name = 'simply_stored_test'
  end
  config.before(:each) do
    #recreate_db
    $performed_queries = []
    CouchPotato.couchrest_database.delete! rescue nil
    CouchPotato.couchrest_database.server.create_db CouchPotato::Config.database_name
  end
end
