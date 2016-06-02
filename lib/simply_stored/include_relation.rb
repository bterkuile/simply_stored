# This file is a tool extension to simply stored. Its intention is to not
# change anything of an existing implementation, but to hugely speedup existing
# implementations. I will illustrate this given the example relation types:
#   Person has_many posts and belongs to a group, Post has many comments, Comment belongs to Writer
# If for a reason you have one page where you want to display all of these objects
# (Person, Post, Comment) you can ofcourse create a view returning all these 
# objects with a smart key for some handy selection. This will probably end up 
# in a controller implementation:
#   @persons = view_result.select{|r| r.is_a?(Person)}
#   @posts = view_result.select{|r| r.is_a?(Post)}
#   @comments = view_result.select{|r| r.is_a?(Comment)}
#   @writers = view_result.select{|r| r.is_a?(Writer)}
# This probably is the recommended way of solving problems in most cases, but sometimes
# because you are lazy or some other obscure reason, you want to use the standard
# SimplyStored behaviour, but not wait too long. For example, if I have a list of 40 persons,
# all having 5 posts that all have 10 comments belonging to a writer, getting all these 
# through their standard relations:
#   @persons.each{ |person| person.posts.each{ |post| post.comments.each{ |comment| puts person.group.name + comment.writer.name } } }
# This will result in 40 * 5 * 10 + 40 = 2040 queries to the database. Doing exactly the same thing using this script
# will look like:
#   @persons = Person.all.include_relation( :group, posts: { conmments: :writer } )
# The useless script above will not take 2040 queries but:
#   1 (persons) + 1 (group) + 1 (posts) + 1 (comments) + 1 (write) = 5 queries
# This makes a difference.
# Issues:
# * Supported relation types:
#   * has_many
#   * belongs_to
# * belongs_to relations, that have no value (nil) will be queried again.
#   That would make the calculation above: 5 + number of persons without a group + number of comments without a writer
# * Little test coverage
class Array
  def include_relation(*relations_arg)
    return self if empty?
    relations = {}
    # Make sure relations is has, process up to two levels for recursion
    # keys with value nil will not have a followup
    relations_arg.each do |arg|
      if arg.is_a?(Symbol)
        relations[arg] = nil
      elsif arg.is_a?(Hash)
        arg.each{|k, v| relations[k] = v}
      elsif arg.is_a?(Array)
        arg.each do |v|
          if arg.is_a?(Symbol)
            relations[v] = nil
          elsif arg.is_a?(Hash)
            arg.each{|k, v| relations[k] = v}
          end
        end
      end
    end

    # For now, assume an array of only one datatype
    klass = first.class

    relations.each do |relation, followup|
      property = klass.properties.find{|p| p.name == relation}
      next unless property
      case property
      when SimplyStored::Couch::HasMany::Property then
        other_class = property.options[:class_name].constantize
        other_property = other_class.properties.find{|p| p.is_a?(SimplyStored::Couch::BelongsTo::Property) && p.options[:class_name] == klass.name}
        #TODO riase when soft_delete is enabled
        view_name = "by_#{other_property.name}_id"
        raise "Cannot include has_many relation #{other_class.name.underscore.pluralize} on #{klass.name} when view :#{view_name}, key: :#{other_property.name}_id is not defined on #{other_class.name}" unless other_class.views[view_name].present?
        relation_objects = other_class.database.view(other_class.send(view_name, keys: collect(&:id))) #not working yet
        relation_objects.include_relation(followup) if followup

        for obj in self
          found_relation_objects = relation_objects.select{|r| r.send("#{other_property.name}_id") == obj.id}

          # Make sure every object has a cached value, no more loading is done
          obj.instance_variable_set("@#{relation}", {all: []}) unless obj.instance_variable_get("@#{relation}").try('[]', :all)
          if found_relation_objects.any?
            obj.instance_variable_get("@#{relation}")[:all] |= found_relation_objects
            if reverse_property_name = other_class.properties.find{|p| p.is_a?(SimplyStored::Couch::BelongsTo::Property) && p.options[:class_name] == klass.name }.try(:name)
              found_relation_objects.each{|relation_object| relation_object.instance_variable_set("@#{reverse_property_name}", obj)}
            end
          end
        end
      when SimplyStored::Couch::BelongsTo::Property then
        key = "#{relation}_id"
        # Collect keys for all objects
        keys = []
        each do |obj|
          next unless obj.is_a?(SimplyStored::Couch) && obj.respond_to?(key)
          keys << obj.send(key)
        end

        # Get from the database
        relation_objects = CouchPotato.database.couchrest_database.bulk_load(keys.compact.uniq)
        relation_objects = Array.wrap(relation_objects['rows']).map{|r| r['doc']}.compact if relation_objects.is_a?(Hash)
        relation_objects ||= [] # Ensure array datatype
        relation_objects.include_relation(followup) if followup

        # Set to attributes
        each do |obj|
          obj.instance_variable_set("@#{relation}", relation_objects.find{|o| o.id == obj.send(key)})
        end
      when SimplyStored::Couch::HasAndBelongsToMany::Property
        if property.options[:storing_keys]
          key = "#{relation.to_s.singularize}_ids"
          # Collect relation ids for all objects
          relation_ids = []
          each do |obj|
            next unless obj.is_a?(SimplyStored::Couch) && obj.respond_to?(key) && obj.send(key).present?
            relation_ids += obj.send(key)
          end
          # Create unique list of ids, this will optimize stuff and synchronize the object ids
          relation_ids = relation_ids.flatten.compact.uniq

          # Get from the database
          relation_objects = CouchPotato.database.couchrest_database.bulk_load(relation_ids)
          relation_objects = Array.wrap(relation_objects['rows']).map{|r| r['doc']}.compact if relation_objects.is_a?(Hash)
          relation_objects ||= [] # Ensure array datatype
          each do |obj|
            obj.instance_variable_set("@#{relation}", {all: relation_objects.select{|o| Array.wrap(obj.send(key)).include?(o.id)}})
          end
          relation_objects.include_relation(followup) if followup
        end
      end
    end
    self
  end

  # Alias method as plural form
  def include_relations(*args)
    include_relation(*args)
  end
end
