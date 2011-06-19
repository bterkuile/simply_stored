$:<<(File.expand_path(File.dirname(__FILE__) + "/lib"))
require File.expand_path(File.dirname(__FILE__) + '/simply_stored/instance_methods')
require File.expand_path(File.dirname(__FILE__) + '/simply_stored/storage')
require File.expand_path(File.dirname(__FILE__) + '/simply_stored/class_methods_base')

# Please move me to a proper location
class String
  def property_name
    underscore.gsub('/','__').gsub('::','__') 
  end
end
module SimplyStored
  VERSION = '0.5.4'
  class Error < RuntimeError; end
  class RecordNotFound < RuntimeError; end
end

require File.expand_path(File.dirname(__FILE__) + '/simply_stored/couch')
