# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.


module Buildr
  VERSION = '1.3.3'.freeze
end

require 'buildr/core/autoload'

autoload(:Builder, 'builder')
autoload(:Config, 'rbconfig')
autoload(:FileUtils, 'fileutils')
autoload(:JRuby, 'jruby')
autoload(:OptionParser, 'optparse')
autoload(:Tempfile, 'tempfile')
autoload(:URI, 'open-uri')
Buildr::Autoload.const '::Zip' => ['zip/zip', 'zip/zipfilesystem']
Buildr::Autoload.const '::Zlib' => ['zlib', 'archive/tar/minitar']

Gem.autoload :SourceInfoCache, 'rubygems/source_info_cache'
$LOADED_FEATURES << 'rubygems/open-uri.rb' # avoid loading rubygems' open-uri

require 'buildr/core_autoload'
require 'buildr/packaging_autoload'
require 'buildr/java_autoload'
require 'buildr/ide_autoload'

# Methods defined in Buildr are both instance methods (e.g. when included in Project)
# and class methods when invoked like Buildr.artifacts().
module Buildr ; extend self ; end


# Everything is loaded, run the boot message chain
Buildr::Application.boot.call self
