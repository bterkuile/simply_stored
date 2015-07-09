require 'spec_helper'

RSpec.describe 'Pagination' do
  it "does not raise error when page and per_page are specified" do
    expect{ User.all(page: 1, per_page: 2) }.not_to raise_error
  end

  it "respond to pagination methods" do
    paginated = User.all(page: 1, per_page: 2 )
    paginated.current_page.should eq 1
    paginated.num_pages.should eq 1
    paginated.per_page.should eq 2
  end

  it "respond to modified pagination methods" do
    paginated = Comment.all(page: 1, per_page: 2 )
    paginated.current_page_modified.should eq 1
    paginated.num_pages_modified.should eq 1
    paginated.per_page_modified.should eq 2
  end

  it "display individual objects on pages with per_page is one" do
    u1 = User.create(title: 'user1', created_at: Time.now )
    u2 = User.create(title: 'user2', created_at: Time.now + 5.minutes )
    u3 = User.create(title: 'user3', created_at: Time.now + 10.minutes )
    User.all.should eq [u1, u2, u3] # normal behaviour
    User.all(per_page: 1).first.should eq u1 # default to page 1
    User.all(page: 2, per_page: 1).first.should eq u2
    User.all(page: 3, per_page: 1).first.should eq u3
  end

  it "paginates all finder" do
    15.times{|i| User.create(title: "user#{i}", created_at: i.minutes.from_now) }
    User.count.should eq 15
    result = User.all(page: 2, per_page: 2)
    result.current_page.should eq 2
    result.per_page.should eq 2
    result.map(&:title).sort.should eq ['user2', 'user3']
    result.total_entries.should eq 15
    result.total_count.should eq 15
    result.num_pages.should eq 8
  end

  it "paginate find_all_by finders" do
    6.times{|i| User.create(title: "user#{i}", homepage: 'http://localhost/1') }
    9.times{|i| User.create(title: "user#{i + 6}", homepage: 'http://localhost/2') }
    User.count.should eq 15
    User.find_all_by_homepage('http://localhost/1').size.should eq 6
    result = User.find_all_by_homepage('http://localhost/1', page: 2, per_page: 2)
    result.current_page.should eq 2
    result.per_page.should eq 2
    result.map(&:title).sort.should eq ['user2', 'user3']
    result.total_entries.should eq 6
    result.total_count.should eq 6
    result.num_pages.should eq 3
  end

  it "paginate has and belongs to many view" do
    server = Server.create
    for klass in 'A'..'Z'
      server.add_network Network.create( klass: klass)
    end
    res = Network.with_pagination_options(startkey: [server.id], endkey: ["#{server.id}\u9999"], page: 1, per_page: 100, reduce: false, include_docs: true) do |o|
      CouchPotato.database.view(Network.association_network_has_and_belongs_to_many_servers(o))
    end
    res.size.should eq 26
  end
  it "paginate has and belongs to many view with non trivial options" do
    server = Server.create
    for klass in 'A'..'Z'
      server.add_network Network.create( klass: klass)
    end
    res = Network.with_pagination_options(startkey: [server.id], endkey: ["#{server.id}\u9999"], page: 2, per_page: 3, reduce: false, include_docs: true) do |o|
      CouchPotato.database.view(Network.association_network_has_and_belongs_to_many_servers(o))
    end
    res.size.should eq 3
  end
end
