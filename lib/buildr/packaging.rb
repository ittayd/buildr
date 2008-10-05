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


Buildr.before_require! 'buildr/packaging/zip' do
  $LOADED_FEATURES.unshift 'ftools' if RUBY_VERSION >= '1.9.0'
  require 'zip/zip'
  require 'zip/zipfilesystem'
end

Buildr.before_require! 'buildr/packaging/tar' do
  require 'buildr/packaging/zip'
  require 'archive/tar/minitar'
end

Buildr.before_require! 'buildr/packaging/artifact' do
  require 'builder'
  require 'buildr/core/project'
  require 'buildr/core/transports'
  require 'buildr/packaging/artifact_namespace'
end

Buildr.before_require! 'buildr/packaging/package' do
  require 'buildr/core/project'
  require 'buildr/core/compile'
  require 'buildr/packaging/artifact'
end

Buildr.before_require! 'buildr/packaging/gems' do
  require 'buildr/packaging/package'
  require 'buildr/packaging/zip'
  require 'rubyforge'
  require 'rubygems/package'
end

Buildr.before_require! 'buildr/packaging/artifact_namespace' do
  require 'buildr/java/version_requirement'
end
