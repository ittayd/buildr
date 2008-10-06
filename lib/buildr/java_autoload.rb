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

  if RUBY_PLATFORM == 'java'
    const '::Java' => ['java', 'jruby', 'buildr/java/jruby']
  else
    const '::Java' => ['rjb', 'buildr/java/rjb']
  end

  # compiler.rb
  const ['Compiler::Javac', 'Javadoc', 'Apt'] => 'buildr/java/compiler'
  task 'buildr/java/compiler', /javadoc/
  method 'buildr/java/compiler', Buildr::Project, :javadoc, :apt
  compiler 'buildr/java/compiler', :javac
  
  # tests.rb
  const ['TestFramework::Java', :JMock, :JUnit, :TestNG] => 'buildr/java/tests'
  task 'buildr/java/tests', /junit/
  tester 'buildr/java/tests', :junit, :testng
  
  # bdd.rb
  const ['TestFramework::JavaBDD', 'TestFramework::JRubyBased', :RSpec, :JtestR, :JBehave] => 'buildr/java/bdd'
  tester 'buildr/java/bdd', :rspec, :jtestr, :jbehave
  
  # packaging.rb  
  const 'Packaging::Java' => 'buildr/java/packaging'
  method 'buildr/java/packaging', Buildr::Project,
  :manifest, :meta_inf, :package_with_sources, :package_with_javadoc,
  :package_as_jar, :package_as_war, :package_as_aar, :package_as_ear, 
  :package_as_javadoc_spec, :package_as_javadoc
  before_require 'buildr/java/packaging' do
    require 'buildr/packaging/package'
    require 'buildr/packaging/zip'
  end
  
  # commands.rb
  const '::Java::Commands' => 'buildr/java/commands'

  # ant.rb
  const :Ant => 'buildr/java/ant'
  method 'buildr/java/ant', (class << Buildr; self; end), :ant
  method 'buildr/java/ant', Buildr::Project, :ant
  
  # deprecated.rb
  const '::Java::JavaWrapper' => 'buildr/java/deprecated'
  
end
