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


require 'rake/gempackagetask'

def spec(platform = RUBY_PLATFORM[/java/] || 'ruby')
  @specs ||= ['ruby', 'java'].inject({}) { |hash, platform|
    $platform = platform
    hash.update(platform=>Gem::Specification.load('buildr.gemspec'))
  }
  @specs[platform]
end


desc 'Compile Java libraries used by Buildr'
task 'compile' do
  puts 'Compiling Java libraries ...'
  sh File.expand_path('_buildr'), '--buildfile=buildr.buildfile', 'compile'
  puts 'OK'
end
file Rake::GemPackageTask.new(spec).package_dir=>'compile'
file Rake::GemPackageTask.new(spec).package_dir_path=>'compile'

# We also need the other package (JRuby if building on Ruby, and vice versa)
Rake::GemPackageTask.new spec(RUBY_PLATFORM =~ /java/ ? 'ruby' : 'java') do |task|
  # Block necessary otherwise doesn't do full job.
end


ENV['incubating'] = 'true'
ENV['staging'] = "people.apache.org:~/public_html/#{spec.name}/#{spec.version}"

task('apache:license').enhance FileList[spec.files].exclude('.class', '.png', '.jar', '.tif', '.textile', '.icns',
   'README', 'LICENSE', 'CHANGELOG', 'DISCLAIMER', 'NOTICE', 'etc/KEYS', 'etc/git-svn-authors')

task 'stage:check' do
  print 'Checking that we have JRuby, Scala and Groovy available ... '
  fail 'Full testing requires JRuby!' unless which('jruby')
  fail 'Full testing requires Scala!' unless which('scala')
  fail 'Full testing requires Groovy!' unless which('groovy')
  puts 'OK'
end

task 'stage:check' do
  # Dependency check for the other platform, i.e. if making a release with Ruby,
  # run dependency checks with JRuby. (Also, good opportunity to upgrade other
  # platform's dependencies)
  sh RUBY_PLATFORM =~ /java/ ? 'ruby' : 'jruby -S rake setup dependency'
end