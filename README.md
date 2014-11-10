Convenience layer for CouchDB on top of CouchPotato.

SimplyStored allows you to persist your objects to CouchDB using an ActiveRecord-like syntax.

In contrast to [CouchPotato](http://github.com/langalex/couch_potato) (on top of it is build)
it supports associations and other syntactic sugar that makes ActiveRecord so appealing.

SimplyStored has also support for S3 attachments.

See also [RockingChair](http://github.com/jweiss/rocking_chair) on how to speed-up your unit tests
by using an in-memory CouchDB backend.

More examples on how to work with SimplyStored can be found [here](http://github.com/jweiss/simply_stored_examples)

This fork
============
This fork of SimplyStored adds some extras to the standard version. A list of this is:

* Pagination, use: Person.all(:page => params[:page], :per\_page => 40) out of the box
* Namespace support, there is working namespace support. It is still in the child phase, but works for me
* Embedded documents. Embed documents but the orm should just work similar (Speedup choice)
* Include relations, Advanced relation including, reducing number of queries (Huge speedup for relations)
* Ancestry for tree structures
* Multi-database support
* Rails 3.1, ruby 1.9.2 tested
* Moving towards ActiveModel, phasing out other/older libraries

Installation
============
Add the following to your bundle file
    gem 'simply_stored', :git => 'git://github.com/bterkuile/simply_stored.git'

#### Using with Rails

Create a config/couchdb.yml:

    default: &default
      validation_framework: :active_model # optional
      split_design_documents_per_view: true # optional

    development:
      <<: *default
      database: http://localhost:5984/development_db
    test:
      <<: *default
      database: http://localhost:5984/test_db
    production:
      <<: *default
      database: <%= ENV['DB_NAME'] %>

#### Rails 3.1.x

Add to your Gemfile:

    # gem 'rails' # we don't want to load activerecord so we can't require rails
    gem 'railties'
    gem 'actionpack'
    gem 'actionmailer'
    gem 'activemodel'
    gem 'simply_stored', :require => 'simply_stored/couch'

Please also see the installation info of [CouchPotato](https://github.com/langalex/couch_potato)

Usage
=============

Require SimplyStored:

    require 'simply_stored'
    CouchPotato::Config.database_name = "http://example.com:5984/name_of_the_db"

From now on you can define classes that use SimplyStored.

Intro
=============

SimplyStored auto-generates views for you and handles all the serialization and de-serialization stuff.

    class User
      include SimplyStored::Couch

      property :login
      property :age
      property :accepted_terms_of_service, :type => :boolean
      property :last_login, :type => Time
    end

    user = User.new(:login => 'Bert', :age => 12, :accepted_terms_of_service => true, :last_login = Time.now)
    user.save

    User.find_by_age(12).login
    # => 'Bert'

    User.all
    # => [user]

    class Post
      include SimplyStored::Couch

      property :title
      property :body

      belongs_to :user
    end

    class User
      has_many :posts
    end

    post = Post.create(:title => 'My first post', :body => 'SimplyStored is so nice!', :user => user)

    user.posts
    # => [post]

    Post.find_all_by_title_and_user_id('My first post', user.id).first.body
    # => 'SimplyStored is so nice!'

    post.destroy

    user.posts(:force_reload => true)
    # => []


Associations
=============

The supported associations are: belongs_to, has_one, has_many, has_many :through, and has_and_belongs_to_many:

    class Post
      include SimplyStored::Couch

      property :title
      property :body

      has_many :posts, :dependent => :destroy
      has_many :users, :through => :posts
      belongs_to :user
    end

    class Comment
      include SimplyStored::Couch

      property :body

      belongs_to :post
      belongs_to :user
    end

    post = Post.create(:title => 'Look ma!', :body => 'I can have comments')

    mike = User.create(:login => 'mike')
    mikes_comment = Comment.create(:user => mike, :post => post, :body => 'Wow, comments are nice')

    john = User.create(:login => 'john')
    johns_comment = Comment.create(:user => john, :post => post, :body => 'They are indeed')

    post.comments
    # => [mikes_comment, johns_comment]

    post.comments(:order => :desc)
    # => [johns_comment, mikes_comment]

    post.comments(:limit => 1)
    # => [mikes_comment]

    post.comment_count
    # => 2

    post.users
    # => [mike, john]

    post.user_count
    # => 2

  n:m relations where the IDs are stored on one part as an array:

    class Server
      include SimplyStored::Couch

      property :hostname

      has_and_belongs_to_many :networks, :storing_keys => true
    end

    class Network
      include SimplyStored::Couch

      property :klass

      has_and_belongs_to_many :servers, :storing_keys => false
    end

    network = Network.create(:klass => "A")
    server = Server.new(:hostname => 'www.example.com')
    network.add_server(server)
    server.network_ids # => [network.id]
    network.servers # => [server]
    server.networks # => [network]

  The array property holding the IDs of the other item will be used to constuct two view to lookup
  the other part. Soft deleting is only supported on the class holding the IDs.  

Custom Associations
=============

    class Document
      include SimplyStored::Couch

      belongs_to :creator, :class_name => "User"
      belongs_to :updater, :class_name => "User"
    end

    d = Document.new
    d.creator = User.first


Validations
=============

Validations are handled by ActiveModel, There are two exceptions:

1. The uniqueness validator
2. The containment validator

The containment validator checks wether an array property is contained within a specified set

```ruby
class Page
  include SimplyStored::Couch

  property :categories

  validates_containment_of :categories, in: %[one two three]
end

Page.new.valid? #=> true
Page.new(categories: %w[one three]).valid? #=> true
Page.new(categories: %w[one four]).valid? #=> false
```

S3 Attachments
=============

SimplyStored supports storing large attachments in Amazon S3.
It uses RightAWS for the interaction with the EC2 API:

```ruby
class Log
  include SimplyStored::Couch
  has_s3_attachment :data, :bucket => 'the-bucket-name',
                           :access_key => 'my-AWS-key-id',
                           :secret_access_key => 'psst!-secret',
                           :location => :eu,
                           :after_delete => :delete,
                           :logger => Logger.new('/dev/null')

end

log = Log.new
log.data = File.read('/var/log/messages')
log.save
# => true

log.data_size
# => 11238132
```
This will create an item on S3 in the specified bucket. The item will use the ID of the log object as the key and the body will be the data attribute. This way you can store big files outside of CouchDB.


Soft delete
=============

SimplyStored also has support for "soft deleting" - much like acts_as_paranoid. Items will then not be deleted but only marked as deleted. This way you can recover them later.

**NOTE: Not tested for a long time (@bterkuile 2014-11-10)**
```ruby
class Document
  include SimplyStored::Couch

  property :title
  enable_soft_delete # will use :deleted_at attribute by default
end

doc = Document.create( title: 'secret project info' )
Document.find_all_by_title('secret project info')
# => [doc]

doc.destroy

Document.find_all_by_title('secret project info')
# => []

Document.find_all_by_title('secret project info', with_deleted: true)
# => [doc]
```

CouchDB - Auto resolution of conflicts on save

SimplyStored now by default retries conflicted save operations if it is possible to resolve the conflict.
Solving the conflict means that if updated were done one different attributes the local object will
refresh those attributes and try to save again. This will be tried two times by default. Afterwards the conflict
exception will be re-raised.

This feature can be controlled on the class level like this:
    User.auto_conflict_resolution_on_save = true | false

If auto_conflict_resolution_on_save is enabled, something like this will work:
```ruby
class Document
  include SimplyStored::Couch

  property :title
  property :content
end

original = Document.create(:title => 'version 1', :content => 'Hi there')

other_client = Document.find(original.id)

original.title = 'version 2'
original.save!

other_client.content = 'A better version'
other_client.save!  # -> this line would fail without auto_conflict_resolution_on_save

other_client.title
# => 'version 2'
```

Ancestry
========
Ancestry is the ability to use tree formed structures.
Since CouchDB is a map/reduce system, creating tree structures is a different technique than the ones apply
by nested set like solution. Given the parent_id approach and many requests to the server always works, it is
far from ideal. Instead this approach uses map reduce to help with fancy queries. Here a short overview:

Example ancestry model, a nested directory structure:
```ruby
class Directory
  include SimplyStored::Couch

  property :name

  has_ancestry
end
```
The `has_ancestry` adds two properties:
* `path_ids`
* `position` indicating the position in within the siblings

Do not edit these properties directly!

### Fetching the full directory structure at once:
```ruby
directories = Directory.full_tree # Loads all pages from database and organizes them into a tree
directories.each do |directory|
  puts directory.tree_depth #=> 0

  # subdirectories in the children attribute
  directory.children.each do |subdirectory|
    puts subdirectory.tree_depth #=> 1
  end
end
```

### Fetching all descendants of a specific directory:
```ruby
Directory.roots #=> [Array with directories not having a parent, can be handy for website menus]
directory  = Directory.find("dir-Pictures")
directory.descendants #=> [all directories below as a flattened array]
directory.subtree #=> [array of children of the directory, but with full subtree already fetched]
```

### Fetching ancestors parents
```ruby
directory.parent_ids #=> [array of ids of the parents]
directory.parents #=> [optimized getter for parent objects as array]
directory.ancestors #=> alias for parents
```

### Assignment
Creating the tree structure can be done by setting parent or children:

```ruby
dir1_1.parent = dir1
dir1_1.parent_id = dir1.iod
dir1.children = [dir1_1]
dir1.add_child dir1_1
```

### Bonus an example used together with the cmtool cms to build a zurb-foundation menu in slim:
```slim
.fixed: nav.top-bar.fixed data-topbar="" role="navigation"
  section.top-bar-section
    ul.left= render partial: "application/menu_item", collection: Page.full_tree
```
having `app/views/application/_menu_item.html.slim`
```slim
- if menu_item.in_menu?
  - if menu_item.children.any?
    li.has-dropdown.not-click
      a href=page_path(menu_item.name) = menu_item.title.presence || menu_item.name
      ul.dropdown= render partial: 'application/menu_item', collection: menu_item.children
  - else
    li
      a href=page_path(menu_item.name) = menu_item.title.presence || menu_item.name
```
License
=============

SimplyStored is licensed under the OpenBSD / two-clause BSD license, modeled after the ISC license. See LICENSE.txt

About
=============

SimplyStored was written by [Mathias Meyer](http://twitter.com/roidrage) and [Jonathan Weiss](http://twitter.com/jweiss) for [Peritor](http://www.peritor.com).
