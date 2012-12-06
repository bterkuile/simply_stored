#require 'active_support/core_ext/hash/except'
module SimplyStored
  module Couch
    module Validations
      class UniquenessValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          other_instance = record.class.send("find_by_#{attribute}", value)
          if other_instance && other_instance != record && other_instance.send(attribute) == value
            record.errors.add(attribute, :taken, options.except(:case_sensitive, :scope).merge(:value => value))
          end
        end
      end
      def validates_uniqueness_of(*attr_names)
        validates_with UniquenessValidator, _merge_attributes(attr_names)
      end
      class ContainmentValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          unless Array.wrap(value) - options[:in] == []
            record.errors.add(attribute, :inclusion, options.except(:in, :within).merge!(:value => value))
          end
        end
      end
      def validates_containment_of(*attr_names)
        validates_with ContainmentValidator, _merge_attributes(attr_names)
      end
    end
  end
end
