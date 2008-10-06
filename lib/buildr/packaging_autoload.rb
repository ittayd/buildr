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
  
  # zip.rb
  const [:ArchiveTask, :ZipTask, :Unzip] => 'buildr/packaging/zip'
  method 'buildr/packaging/zip', Buildr, :zip, :unzip
  before_require 'buildr/packaging/zip' do
    require 'zip/zip'
  end

  # tar.rb
  const :TarTask => 'buildr/packaging/tar'
  method 'buildr/packaging/tar', Buildr, :tar
  before_require 'buildr/packaging/tar' do
    require 'archive/tar/minitar'
  end

  # artifact.rb
  const [:ActsAsArtifact, :Artifact, :Repositories] => 'buildr/packaging/artifact'
  method 'buildr/packaging/artifact', Buildr,
  :repositories, :artifact, :artifacts, :transitive, :group, :install, :upload
  task 'buildr/packaging/artifact', /artifacts/, /(un)?install/, 'upload'

  # package.rb
  const :Package => 'buildr/packaging/package'
  method 'buildr/packaging/package', Buildr::Project,
  :id, :version, :version=, :group, :group=, :package, :packages
  task 'buildr/packaging/package', /:?package:?/
  
  # gems.rb
  const [:PackageAsGem, :PackageGemTask] => 'buildr/packaging/gems'
  method 'buildr/packaging/gems', Buildr::Project, :package_as_gem

  # artifact_namespace.rb
  const :ArtifactNamespace => 'buildr/packaging/artifact_namespace'
  
end
