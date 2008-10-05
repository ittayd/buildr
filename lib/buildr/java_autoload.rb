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
  Buildr::Autoload.const '::Java' => ['java', 'jruby', 'buildr/java/jruby']
else
  Buildr::Autoload.const '::Java' => ['rjb', 'buildr/java/rjb']
end

# compiler.rb
Buildr::Autoload.const ['Compiler::Javac', 'Javadoc', 'Apt'] => 'buildr/java/compiler'
Buildr::Autoload.task 'buildr/java/compiler', /javadoc/
Buildr::Autoload.method 'buildr/java/compiler', Buildr::Project, :javadoc, :apt
Buildr::Autoload.compiler 'buildr/java/compiler', :javac

# tests.rb
Buildr::Autoload.const ['TestFramework::Java', :JMock, :JUnit, :TestNG] => 'buildr/java/tests'
Buildr::Autoload.task 'buildr/java/tests', /junit/
Buildr::Autoload.tester 'buildr/java/tests', :junit, :testng

# bdd.rb
Buildr::Autoload.const ['TestFramework::JavaBDD', 'TestFramework::JRubyBased', :RSpec, :JtestR, :JBehave] => 'buildr/java/bdd'
Buildr::Autoload.tester 'buildr/java/bdd', :rspec, :jtestr, :jbehave

# packaging.rb
Buildr.before_require 'buildr/java/packaging' do
  require 'buildr/packaging/package'
  require 'buildr/packaging/zip'
end

Buildr::Autoload.const 'Packaging::Java' => 'buildr/java/packaging'
Buildr::Autoload.method 'buildr/java/packaging', Buildr::Project,
:manifest, :meta_inf, :package_with_sources, :package_with_javadoc,
:package_as_jar, :package_as_war, :package_as_aar, :package_as_ear, 
:package_as_javadoc_spec, :package_as_javadoc

# commands.rb
Buildr::Autoload.const '::Java::Commands' => 'buildr/java/commands'

# deprecated.rb
Buildr::Autoload.const '::Java::JavaWrapper' => 'buildr/java/deprecated'
