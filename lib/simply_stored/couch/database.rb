# Intended to create multi-database option on top of Potato
module SimplyStored
  module Couch
    module Database
      def database
        CouchPotato.database
      end
    end
  end
end
