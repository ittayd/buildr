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

# zip.rb
$LOADED_FEATURES.unshift 'ftools' if RUBY_VERSION >= '1.9.0'
Buildr::Autoload.const [:ArchiveTask, :ZipTask, :Unzip] => 'buildr/packaging/zip'
Buildr::Autoload.method 'buildr/packaging/zip', Buildr, :zip, :unzip

# tar.rb
Buildr::Autoload.const :TarTask => 'buildr/packaging/tar'
Buildr::Autoload.method 'buildr/packaging/tar', Buildr, :tar

# artifact.rb
Buildr::Autoload.const [:ActsAsArtifact, :Artifact, :Repositories] => 'buildr/packaging/artifact'
Buildr::Autoload.method 'buildr/packaging/artifact', Buildr,
:repositories, :artifact, :artifacts, :transitive, :group, :install, :upload
Buildr::Autoload.task 'buildr/packaging/artifact', 'artifacts', /(un)?install/, 'upload'

# package.rb
Buildr::Autoload.const :Package => 'buildr/packaging/package'
Buildr::Autoload.method 'buildr/packaging/package', Buildr::Project, 
:id, :version, :version=, :group, :group=, :package, :packages
Buildr::Autoload.task 'buildr/packaging/package', /:?package:?/

# gems.rb
Buildr::Autoload.const [:PackageAsGem, :PackageGemTask] => 'buildr/packaging/gems'

# artifact_namespace.rb
Buildr::Autoload.const :ArtifactNamespace => 'buildr/packaging/artifact_namespace'

