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

# Allow Buildr methods and constants to be accessed from any object during tests
class Object #:nodoc:
  Buildr.constants.each { |c| const_set c, Buildr.const_get(c) unless const_defined?(c) }
end

# We need to run all tests inside a sandbox, tacking a snapshot of Buildr before the test,
# and restoring everything to its previous state after the test. Damn state changes.
module Sandbox #:nodoc:

  extend Buildr
  
  # The local repository we use for testing is void of any artifacts, which will break given
  # that the code requires several artifacts. So we establish them first using the real local
  # repository and cache these across test cases.
  Buildr.application.instance_eval { @rakefile = File.expand_path('buildfile') }
  Buildr.application.send :init
  repositories.remote << 'http://repo1.maven.org/maven2'
  repositories.remote << 'http://scala-tools.org/repo-releases'
  
  class << self
    def included(spec)
      init
      spec.before(:each) { setup }
      spec.after(:each) { reset }
    end

    def without_context
      old, Context.current = Context.current, nil
      begin
        yield
      ensure
        Context.current = old
      end
    end

    def init
      Java.load # Anything added to the classpath.
      task('buildr:scala:download').invoke
      artifacts(TestFramework.frameworks.map(&:dependencies).flatten, JUnit.ant_taskdef).each { |a| file(a).invoke }
    end
        
    def sandbox
      @sandbox ||= Hash.new.tap do |sandbox|
        sandbox[:application] = Buildr.application
        
        sandbox[:original_dir] = Dir.pwd
        sandbox[:tmp_dir] = File.expand_path("../tmp-#{Process.pid}", File.dirname(__FILE__))
        sandbox[:home_dir] = File.expand_path("home", sandbox[:tmp_dir])
        
        sandbox[:load_path] = $LOAD_PATH.clone
        sandbox[:loaded_features] = $LOADED_FEATURES.clone
        
        sandbox[:env_keys] = ENV.keys
        ['DEBUG', 'TEST', 'HTTP_PROXY', 'USER'].each { |k| ENV.delete(k) ; ENV.delete(k.downcase) }
        
        sandbox[:artifacts] = Artifact.send(:defined_artifacts).clone
        sandbox[:init] = Application.init.messages.clone
        sandbox[:before_define] = Project.before_define.messages.clone
        sandbox[:after_define] = Project.after_define.messages.clone
      end
    end
  end

  def sandbox
    Sandbox.sandbox
  end

  def setup
    # Create a temporary directory where we can create files, e.g,
    # for projects, compilation. We need a place that does not depend
    # on the current directory.
    FileUtils.rm_rf  sandbox[:tmp_dir], :verbose => false
    ENV['HOME'] = sandbox[:home_dir]
    FileUtils.mkpath sandbox[:home_dir]
    Dir.chdir sandbox[:tmp_dir]
    
    # Create a new buildr application
    app = Application.new

    # Restore static message chains.
    Application.init.messages.replace sandbox[:init]
    Project.before_define.messages.replace sandbox[:before_define]
    Project.after_define.messages.replace sandbox[:after_define]

    app.send :init

    # Use the defined artifacts so that they wont be donwloaded again
    Artifact.send(:defined_artifacts).update sandbox[:artifacts]

    app.instance_eval { @rakefile = File.expand_path('buildfile') }
    
    # Remove testing local repository, and reset all repository settings.
    repositories.instance_eval { @local = @remote = @release_to = nil }
    options.proxy.http = nil
        
    # Don't output crap to the console.
    trace false
    verbose false
  end

  def reset
    Buildr.options.test = nil

    # restore the load path
    $LOAD_PATH.replace sandbox[:load_path]
    $LOADED_FEATURES.replace sandbox[:loaded_features]
    
    # restore the environment
    (ENV.keys - sandbox[:env_keys]).each { |key| ENV.delete key }

    # remove the test directory
    FileUtils.rm_rf sandbox[:tmp_dir]
    Dir.chdir sandbox[:original_dir]
  end

end
