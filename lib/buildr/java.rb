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


if RUBY_PLATFORM == 'java'
  Buildr.before_require! 'buildr/java/jruby' do
    require 'java'
    require 'jruby'
  end
else
  Buildr.before_require! 'buildr/java/rjb' do
    require 'rjb'
  end
end

Buildr.before_require! 'buildr/java/compiler' do 
  require 'buildr/core/project'
  require 'buildr/core/common'
  require 'buildr/core/compile'
  require 'buildr/packaging'
end

Buildr.before_require! 'buildr/java/tests' do
  require 'buildr/core/build'
  require 'buildr/core/compile'
  require 'buildr/java/ant'
end

Buildr.before_require! 'buildr/java/bdd' do 
  require 'buildr/java/tests'
  require 'buildr/java/test_result'
end

Buildr.before_require! 'buildr/java/packaging' do
  require 'buildr/packaging'
end

Buildr.before_require! 'buildr/java/commands'

Buildr.before_require! 'buildr/java/deprecated' do
  require 'buildr/core/project'
end

Buildr.before_require! 'buildr/java/ant' do
  require 'antwrap'
  require 'buildr/core/project'
  require 'buildr/core/help'
end
