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


desc 'Clean up all temporary directories used for running tests, creating documentation, packaging, etc.'
task 'clobber'

package = Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
  pkg.need_zip = true
end

desc 'Install the package locally'
task 'install'=>['setup', "#{package.package_dir}/#{package.gem_file}"] do |task|
  print "Installing #{spec.name} ... "
  args = [Config::CONFIG['ruby_install_name'], '-S', 'gem', 'install', "#{package.package_dir}/#{package.gem_file}"]
  args.unshift('sudo') unless windows?
  sh *args
  puts 'Done'
end

desc 'Uninstall previously installed packaged'
task 'uninstall' do |task|
  print "Uninstalling #{spec.name} ... "
  args = [Config::CONFIG['ruby_install_name'], '-S', 'gem', 'uninstall', spec.name, '--version', spec.version.to_s]
  args.unshift('sudo') unless windows?
  sh *args
  puts 'Done'
end
