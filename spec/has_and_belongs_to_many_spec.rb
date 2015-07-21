require 'spec_helper'

describe "has_and_belongs_to_many" do

  context "with has_and_belongs_to_many" do
    it "create a fetch method for the associated objects" do
      server = Server.new
      server.should respond_to :networks

      network = Network.new
      network.should respond_to :servers
    end

    it "raise an error if another property with the same name already exists" do
      expect {
        class ::DoubleHasAdnBelongsToManyServer
          include SimplyStored::Couch
          property :other_users
          has_and_belongs_to_many :other_users
        end
      }.to raise_error RuntimeError
    end

    it "fetch the associated objects" do
      network = Network.create(klass: "A")
      3.times {
        server = Server.new
        server.network_ids = [network.id]
        server.save!
      }
      network.servers.size.should eq 3
    end

    it "not add empty relations" do
      # Checkbox assignment often gives an empty one to
      # set array to [] when none is selected
      server = Server.new
      network = Network.create(klass: "Q")
      server.network_ids = ["", nil, network.id]
      server.network_ids.size.should eq 1
      server.save!
      server.networks.size.should eq 1
    end

    it "fetch the associated objects from the other side of the relation" do
      network = Network.create(klass: "A")
      3.times {
        server = Server.new
        server.network_ids = [network.id]
        server.save!
      }
      Server.first.networks.size.should eq 1
    end

    it "set the parent object on the clients cache" do
      expect( Network ).not_to receive(:find)
      network = Network.create(klass: "A")
      3.times {
        server = Server.new
        server.add_network(network)
      }
      network.servers.first.networks.first.should eq network
    end

    it "set the parent object on the clients cache from the other side of the relation" do
      expect( Server ).not_to receive(:find)
      network = Network.create(klass: "A")
      3.times {
        server = Server.new
        network.add_server(server)
      }
      network.servers.first.networks.first.should eq network
    end

    it "work relations from both sides" do
      network_a = Network.create(klass: "A")
      network_b = Network.create(klass: "B")
      3.times {
        server = Server.new
        server.add_network(network_a)
        server.add_network(network_b)
      }
      network_a.servers.size.should eq 3
      network_a.servers.each do |server|
        server.networks.size.should eq 2
      end
      network_b.servers.size.should eq 3
      network_b.servers.each do |server|
        server.networks.size.should eq 2
      end
    end

    it "work relations from both sides - regardless from where the add was called" do
      network_a = Network.create(klass: "A")
      network_b = Network.create(klass: "B")
      3.times {
        server = Server.new
        network_a.add_server(server)
        network_b.add_server(server)
      }
      network_a.servers.size.should eq 3
      network_a.servers.each do |server|
        server.networks.size.should eq 2
      end
      network_b.servers.size.should eq 3
      network_b.servers.each do |server|
        server.networks.size.should eq 2
      end
    end

    context "limit" do

      it "be able to limit the result set" do
        network = Network.create(klass: "A")
        3.times {
          server = Server.new
          server.add_network(network)
        }
        network.servers(limit: 2).size.should eq 2
      end

      it "use the given options in the cache-key" do
        network = Network.create(klass: "A")
        3.times {
          server = Server.new
          server.add_network(network)
        }
        network.servers(limit: 2).size.should eq 2
        network.servers(limit: 3).size.should eq 3
      end

      it "be able to limit the result set - for both directions" do
        network_a = Network.create(klass: "A")
        network_b = Network.create(klass: "B")
        3.times {
          server = Server.new
          server.add_network(network_a)
          server.add_network(network_b)
        }
        network_a.servers(limit: 2).size.should eq 2
        network_a.servers(limit: 3).size.should eq 3

        network_a.servers.first.networks(limit: 2).size.should eq 2
        network_a.servers.first.networks(limit: 1).size.should eq 1
      end
    end

    context "order" do
      before do
        @network = Network.create(klass: "A")
        @network.created_at = Time.local(2000)
        @network.save!
        @network_b = Network.create(klass: "B")
        @network_b.created_at = Time.local(2002)
        @network_b.save!
        3.times do |i|
          server = Server.new
          server.add_network(@network)
          server.add_network(@network_b)
          server.created_at = Time.local(2000 + i)
          server.save!
        end
      end

      it "support different order" do
        expect{ @network.servers(order: :asc) }.not_to raise_error
        expect{ @network.servers(order: :desc) }.not_to raise_error
      end

      it "reverse the order if :desc" do
        @network.servers(order: :desc).map(&:id).should eq @network.servers(order: :asc).map(&:id).reverse
        server = @network.servers.first
        server.networks(order: :desc).map(&:id).should eq server.networks(order: :asc).map(&:id).reverse
      end

      it "work with the limit option" do
        server = Server.new
        server.add_network(@network)
        server.add_network(@network_b)
        @network.servers(order: :asc, limit: 3).map(&:id).reverse.should_not eq @network.servers(order: :desc, limit: 3).map(&:id)
        server.networks(order: :asc, limit: 1).map(&:id).reverse.should_not eq server.networks(order: :desc, limit: 1).map(&:id)
      end
    end

    it "verify the given options for the accessor method" do
      network = Network.create(klass: "A")
      expect{ network.servers(foo: :bar) }.to raise_error ArgumentError
    end

    it "verify the given options for the association defintion" do
      expect {
        Network.instance_eval do
          has_and_belongs_to_many :foo, bar: :do
        end
      }.to raise_error ArgumentError
    end

    it "only fetch objects of the correct type" do
      network = Network.create(klass: "A")
      server = Server.new
      server.network_ids = [network.id]
      server.save!

      comment = Comment.new
      comment.network = network
      comment.save!

      network.servers.size.should eq 1
    end

    it "getter should user cache" do
      network = Network.create(klass: "A")
      server = Server.new
      server.network_ids = [network.id]
      server.save!
      network.servers
      network.instance_variable_get("@servers")[:all].should eq [server]
    end

    it "add methods to handle associated objects" do
      network = Network.create(klass: "A")
      network.should respond_to :add_server
      network.should respond_to :remove_server
      network.should respond_to :remove_all_servers
    end

    it "add methods to handle associated objects - for the other side too" do
      server = Server.create
      server.should respond_to :add_network
      server.should respond_to :remove_network
      server.should respond_to :remove_all_networks
    end

    it 'ignore the cache when requesting explicit reload' do
      network = Network.create(klass: "A")
      network.servers.should eq []
      server = Server.new
      server.network_ids = [network.id]
      server.save!
      network.servers(force_reload: true).should eq [server]
    end

    it "use the correct view when handling inheritance" do
      network = Network.create
      subnet = Subnet.create
      server = Server.new
      server.network_ids = [network.id]
      server.save!
      network.servers.size.should eq 1
      server.update_attributes(network_ids: nil, subnet_ids: [subnet.id])
      subnet.servers.size.should eq 1
    end

    context "when adding items" do
      it "add the item to the internal cache" do
        network = Network.new(klass: "C")
        server = Server.new
        network.servers.should eq []
        network.add_server(server)
        network.servers.should eq [server]
        network.instance_variable_get("@servers")[:all].should eq [server]
      end

      it "raise an error when the added item is not an object of the expected class" do
        network = Network.new
        expect{ network.add_server('foo') }.to raise_error ArgumentError, "expected Server got String"
      end

      it "save the added item" do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)
        server.should_not be_new_record
      end

      it "save the added item - from both directions" do
        server = Server.new
        network = Network.create(klass: "A")
        server.add_network(network)
        server.should_not be_new_record
      end

      it 'set the forein key on the added object' do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)
        server.network_ids.should eq [network.id]
      end

      it 'set the forein key on the added object - from both directions' do
        server = Server.new
        network = Network.create(klass: "A")
        server.add_network(network)
        server.network_ids.should eq [network.id]
      end

      it "adding multiple times doesn't hurt" do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)
        network.add_server(server)
        server.add_network(network)
        server.network_ids.should eq [network.id]
        Server.find(server.id).network_ids.should eq [network.id]
      end
    end

    context "when removing items" do
      it "should unset the foreign key" do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)

        network.remove_server(server)
        server.network_ids.should eq []
      end

      it "should unset the foreign key - from both directions" do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)

        server.remove_network(network)
        server.network_ids.should eq []
      end

      it "remove the item from the cache" do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)
        network.servers.should include server
        network.remove_server(server)
        network.servers.any?{|s| server.id == s.id}.should_not be true
        network.instance_variable_get("@servers")[:all].should eq []
      end

      it "remove the item from the cache - from both directions" do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)
        server.networks.should include(network)
        server.remove_network(network)
        server.networks.any?{|n| network.id == n.id}.should_not be true
        server.instance_variable_get("@networks")[:all].should eq []
      end

      it "save the removed item with the nullified foreign key" do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)

        network.remove_server(server)
        server = Server.find(server.id)
        server.network_ids.should eq []
      end

      it "save the removed item with the nullified foreign key - from both directions" do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)

        server.remove_network(network)
        server = Server.find(server.id)
        server.network_ids.should eq []
      end

      it 'raise an error when another object is the owner of the object to be removed' do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)

        other_server = Server.create
        expect{ network.remove_server(other_server) }.to raise_error ArgumentError
      end

      it 'raise an error when another object is the owner of the object to be removed - from both directions' do
        server = Server.new
        network = Network.create(klass: "A")
        network.add_server(server)

        other_network = Network.create
        expect{ server.remove_network(other_network) }.to raise_error ArgumentError
      end

      it 'raise an error when the object is the wrong type' do
        expect{ Network.new.remove_server('foo') }.to raise_error ArgumentError, "expected Server got String"
        expect{ Server.new.remove_network('foo') }.to raise_error ArgumentError, "expected Network got String"
      end
    end

    context "when removing all items" do
      it 'nullify the foreign keys on all referenced items' do
        server_1 = Server.new
        server_2 = Server.new
        network = Network.create(klass: "A")
        network.add_server(server_1)
        network.add_server(server_2)
        network.remove_all_servers
        server_1 = Server.find(server_1.id)
        server_2 = Server.find(server_2.id)
        server_1.network_ids.should eq []
        server_2.network_ids.should eq []
      end

      it 'nullify the foreign keys on all referenced items - from both directions' do
        server_1 = Server.new
        server_2 = Server.new
        network = Network.create(klass: "A")
        network.add_server(server_1)
        network.add_server(server_2)
        server_1.remove_all_networks
        server_1 = Server.find(server_1.id)
        server_2 = Server.find(server_2.id)
        server_1.network_ids.should eq []
        server_2.network_ids.should eq [network.id]
      end

      it 'empty the cache' do
        server_1 = Server.new
        server_2 = Server.new
        network = Network.create(klass: "A")
        network.add_server(server_1)
        network.add_server(server_2)
        network.remove_all_servers
        network.servers.should eq []
        network.instance_variable_get("@servers")[:all].should eq []
      end

      it 'empty the cache - from both directions' do
        server_1 = Server.new
        server_2 = Server.new
        network = Network.create(klass: "A")
        network.add_server(server_1)
        network.add_server(server_2)
        server_1.remove_all_networks
        server_1.networks.should eq []
        server_1.instance_variable_get("@networks")[:all].should eq []
      end

      context "when counting" do
        before do
          @network = Network.create(klass: "C")
          @server = Server.create
        end

        it "define a count method" do
          @network.should respond_to :server_count
          @server.should respond_to :network_count
        end

        it "cache the result" do
          @network.server_count.should eq 0
          Server.create(network_ids: [@network.id])
          @network.server_count.should eq 0
          @network.instance_variable_get("@server_count").should eq 0
          @network.instance_variable_set("@server_count", nil)
          @network.server_count.should eq 1
        end

        it "cache the result - from both directions" do
          @server.network_count.should eq 0
          @server.network_ids = [@network.id]
          @server.save!
          @server.network_count.should eq 0
          @server.instance_variable_get("@network_count").should eq 0
          @server.instance_variable_set("@network_count", nil)
          @server.network_count.should eq 1
        end

        it "force reload even if cached" do
          @network.server_count.should eq 0
          Server.create(network_ids: [@network.id])
          @network.server_count.should eq 0
          @network.server_count(force_reload: true).should eq 1
        end

        it "force reload even if cached - from both directions" do
          @server.network_count.should eq 0
          @server.network_ids = [@network.id]
          @server.save!
          @server.network_count.should eq 0
          @server.network_count(force_reload: true).should eq 1
        end

        it "count the number of belongs_to objects" do
          @network.server_count(force_reload: true).should eq 0
          Server.create(network_ids: [@network.id])
          @network.server_count(force_reload: true).should eq 1
          Server.create(network_ids: [@network.id])
          @network.server_count(force_reload: true).should eq 2
          Server.create(network_ids: [@network.id])
          @network.server_count(force_reload: true).should eq 3
        end

        it "count the number of belongs_to objects - from both directions" do
          @server.network_count(force_reload: true).should eq 0
          @server.network_ids = [@network.id]
          @server.save!
          @server.network_count(force_reload: true).should eq 1
          @server.network_ids = [@network.id, Network.create.id]
          @server.save!
          @server.network_count(force_reload: true).should eq 2
        end

        it "not count non-releated objects" do
          Server.all.each{|s| s.delete}
          network_1 = Network.create(klass: "A")
          network_2 = Network.create(klass: "B")
          server_1 = Server.create
          server_2 = Server.create(network_ids: [network_1.id])
          server_3 = Server.create(network_ids: [network_1.id, network_2.id])
          Server.count.should eq 3
          network_1.server_count.should eq 2
          network_2.server_count.should eq 1
          server_1.network_count.should eq 0
          server_2.network_count.should eq 1
          server_3.network_count.should eq 2
        end

        it "not count deleted objects" do
          network = Network.create(klass: "A")
          server = Server.create(network_ids: [network.id])
          network.server_count(force_reload: true).should eq 1
          server.delete
          network.server_count(force_reload: true).should eq 0
        end

        it "not count deleted objects - from both directions" do
          network = Network.create(klass: "A")
          server = Server.create(network_ids: [network.id])
          server.network_count(force_reload: true).should eq 1
          network.delete
          server.network_count(force_reload: true).should eq 0
        end

      end
    end

    context "with deleted" do
      it "not fetch deleted objects" do
        require 'matrix'
        network = Network.create(klass: "A")
        server = Server.new
        server.network_ids = [network.id]
        server.save!
        network.servers(force_reload: true).size.should eq 1
        expect{ server.delete }.to change{ Vector[Network.count, Server.count] }.by Vector[0, -1]
        network.servers(force_reload: true).size.should eq 0
      end

      it "not fetch deleted objects - from both directions" do
        require 'matrix'
        network = Network.create(klass: "A")
        server = Server.new
        server.network_ids = [network.id]
        server.save!
        server.networks(force_reload: true).size.should eq 1
        expect{ network.delete }.to change{ Vector[Network.count, Server.count] }.by Vector[-1, 0]
        server.networks(force_reload: true).size.should eq 0
        server.reload.network_ids.should eq []
      end
    end


    context "with soft deleted" do

      it "not load soft deleted - items storing keys" do
        network = Network.create
        router = Router.new
        network.add_router(router)
        network.routers.size.should eq 1
        router.delete
        Router.count.should eq 0
        Router.count(with_deleted: true).should eq 1
        network.routers(force_reload: true).size.should eq 0
        network.routers(force_reload: true, with_deleted: true).size.should eq 1
        router.delete!
        network.routers(force_reload: true, with_deleted: true).size.should eq 0
      end

      it "not count soft deleted - items storing keys" do
        network = Network.create
        router = Router.new
        network.add_router(router)
        network.routers.size.should eq 1
        router.delete
        Router.count.should eq 0
        Router.count(with_deleted: true).should eq 1
        network.router_count(force_reload: true).should eq 0
        network.router_count(force_reload: true, with_deleted: true).should eq 1
        router.delete!
        network.router_count(force_reload: true, with_deleted: true).should eq 0
      end

      it "not load soft deleted - items not storing keys: not supported" do
        book = Book.create
        author = Author.create
        author.add_book(book)
        author.delete
        Author.count.should eq 0
        Author.count(with_deleted: true).should eq 1
        book.authors(force_reload: true).size.should eq 0
        book.authors(force_reload: true, with_deleted: true).size.should eq 0
      end

      it "not count soft deleted - items not storing keys: not supported" do
        book = Book.create
        author = Author.create
        author.add_book(book)
        author.delete
        Author.count.should eq 0
        Author.count(with_deleted: true).should eq 1
        book.author_count(force_reload: true).should eq 0
        book.author_count(force_reload: true, with_deleted: true).should eq 0
      end

    end

    context "when not persisted" do
      it "not return objects when a record is not persisted on storing keys" do
        router = Router.new
        other_router = Router.create
        network = Network.create
        other_router.network_ids = [network.id]
        other_router.save
        router.networks.should be_empty
      end
      it "not return objects when a record is not persisted on non storing keys" do
        router = Router.create
        other_router = Router.create
        other_network = Network.create
        other_router.network_ids = [other_network.id]
        network = Network.new
        network.routers.should be_empty
      end
    end

  end
end
