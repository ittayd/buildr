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

Buildr.Autoload do
  
  # common.rb
  const :Util => 'buildr/core/util', :ConcatTask => 'buildr/core/common'
  method 'buildr/core/common', Buildr, :struct, :write, :read, :download, :concat

  # project.rb
  require 'buildr/core/project'

  # environment.rb
  require 'buildr/core/environment'

  # help.rb
  const :Help => 'buildr/core/help'
  method 'buildr/core/help', Buildr, :help
  task 'buildr/core/help', /^help(:(projects|tasks))?$/

  # build.rb
  const [:Build, :Svn, :Release] => 'buildr/core/build'
  method 'buildr/core/build', Buildr::Options, :parallel
  task 'buildr/core/build', /default|parallel|release|build|clean/

  # filter.rb
  const :Filter => 'buildr/core/filter'
  method 'buildr/core/filter', Buildr, :filter

  # compile.rb
  const [:CompilerTask, :CompileTask, :ResourcesTask, :Compile, :Compiler, 'Compiler::Base'] => 'buildr/core/compile'
  method 'buildr/core/compile', Buildr::Project, :compile, :resources
  task 'buildr/core/compile', /(compile|resources)$/

  # test.rb
  const [:TestFramework, :TestTask, :IntegrationTestTask, :Test] => 'buildr/core/test'
  method 'buildr/core/test', Buildr, :integration
  task 'buildr/core/test', 'test', /(^|:)test:/

  # checks.rb
  const :Checks => 'buildr/core/checks'

  # generate.rb
  const :Generate => 'buildr/core/generate'
  task 'buildr/core/generate', 'generate'

  # transports.rb
  const '::URI::NotFoundError' => 'buildr/core/transports'
  after_require 'net/http' do
    require 'buildr/core/transports'
  end

  # progressbar.rb
  const '::ProgressBar' => 'buildr/core/progressbar'

end
