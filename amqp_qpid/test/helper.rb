DIR=File.dirname(__FILE__)
LIB_DIR=File.expand_path(File.join(DIR, '..', 'lib'))
PLUGIN_DIR=File.join(LIB_DIR, 'fluent', 'plugin')
CONFIG_FILE=File.expand_path(File.join(DIR, "fluent.conf"))

$LOAD_PATH.unshift(LIB_DIR)
$LOAD_PATH.unshift(PLUGIN_DIR)
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'test/unit'
require 'qpid_proton'
require 'qpid_proton_extra'
