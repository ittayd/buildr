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


Buildr.before_require! 'buildr/core/common' do
  require 'rake'
  require 'tempfile'
  require 'open-uri'
  $LOADED_FEATURES << 'rubygems/open-uri.rb' # avoid loading rubygems' open-uri
  require 'buildr/core/ruby_ext'
  require 'buildr/core/util'
end

Buildr.before_require! 'buildr/core/message'

Buildr.before_require! 'buildr/core/application' do
  require 'buildr/core/rake_ext'
  require 'buildr/core/application_cli'
  Gem.autoload :SourceInfoCache, 'rubygems/source_info_cache'
end

Buildr.before_require! 'buildr/core/project' do
  require 'buildr/core/common'
end

Buildr.before_require! 'buildr/core/environment' do
  require 'yaml'
end

Buildr.before_require! 'buildr/core/help' do
  require 'buildr/core/common'
  require 'buildr/core/project'
end

Buildr.before_require! 'buildr/core/build' do
  require 'buildr/core/project'
  require 'buildr/core/common'
  require 'buildr/core/checks'
  require 'buildr/core/environment'
end

Buildr.before_require! 'buildr/core/filter'

Buildr.before_require! 'buildr/core/compile' do
  require 'buildr/core/common'
end

Buildr.before_require! 'buildr/core/test' do 
  require 'buildr/core/project'
  require 'buildr/core/build'
  require 'buildr/core/compile'
end

Buildr.before_require! 'buildr/core/checks' do
  require 'buildr/core/project'
  require 'buildr/packaging/zip'
  #require 'test/unit'
  require 'spec/matchers'
  require 'spec/expectations'
end

Buildr.before_require! 'buildr/core/generate' do
  require 'buildr/java/pom'
end

