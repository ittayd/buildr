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


# common.rb
Buildr::Autoload.const :Util => 'buildr/core/util', :ConcatTask => 'buildr/core/common'
Buildr::Autoload.method 'buildr/core/common', Buildr, :struct, :write, :read, :download, :concat

# project.rb
require 'buildr/core/project'

# environment.rb
require 'buildr/core/environment'

# help.rb
Buildr::Autoload.const :Help => 'buildr/core/help'
Buildr::Autoload.method 'buildr/core/help', Buildr, :help
Buildr::Autoload.task 'buildr/core/help', /^help(:(projects|tasks))?$/

# build.rb
Buildr::Autoload.const [:Build, :Svn, :Release] => 'buildr/core/build'
Buildr::Autoload.method 'buildr/core/build', Buildr::Options, :parallel
Buildr::Autoload.task 'buildr/core/build', /default|parallel|release|build|clean/

# filter.rb
Buildr::Autoload.const :Filter => 'buildr/core/filter'
Buildr::Autoload.method 'buildr/core/filter', Buildr, :filter

# compile.rb
Buildr::Autoload.const [:CompilerTask, :CompileTask, :ResourcesTask, :Compile, :Compiler, 'Compiler::Base'] => 'buildr/core/compile'
Buildr::Autoload.method 'buildr/core/compile', Buildr::Project, :compile, :resources
Buildr::Autoload.task 'buildr/core/compile', /(compile|resources)$/

# test.rb
Buildr::Autoload.const [:TestFramework, :TestTask, :IntegrationTestTask, :Test] => 'buildr/core/test'
Buildr::Autoload.method 'buildr/core/test', Buildr, :integration
Buildr::Autoload.task 'buildr/core/test', 'test', /(^|:)test:/

# checks.rb
Buildr::Autoload.const :Checks => 'buildr/core/checks'

# generate.rb
Buildr::Autoload.const :Generate => 'buildr/core/generate'
Buildr::Autoload.task 'buildr/core/generate', 'generate'

