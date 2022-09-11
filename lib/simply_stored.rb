# Please move me to a proper location
class String
  def property_name
    underscore.gsub('/','__').gsub('::','__')
  end
end

unless defined?(SimplyStored)
  $:<<(File.expand_path(File.dirname(__FILE__) + "/lib"))
  require 'simply_stored/instance_methods'
  require 'simply_stored/storage'
  require 'simply_stored/class_methods_base'

  module SimplyStored
    VERSION = '1.0.0'
    class Error < RuntimeError; end
    class RecordNotFound < RuntimeError; end
    class NotImplementedError < RuntimeError; end
  end

  require 'simply_stored/couch'
  require 'core_ext/time'
  require 'core_ext/date'
end
