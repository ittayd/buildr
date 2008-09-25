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


module Buildr 

  # This Addon extends Buildr with a -C command line option like `make', `tar'
  # and other unix programs have.
  # 
  #
  # Usage:
  #    buildr -R buildr/path --help
  #
  # Note: This file must be loaded using the --require-early (-R) option since it
  # needs to be run before command line argument processing takes place.
  #
  # The --directory (-C) option instructs buildr to change the working directory
  # before trying to find the buildfile. This option can be useful when invoking
  # buildr from other build systems, most likely by your system package manager.
  #
  # The --project (-p) option specifies the default project to run tasks on, for example:
  # instead of:
  #
  #   buildr deep:down:project:clean deep:down:project:compile deep:down:project:api:install
  # 
  # you can do
  #
  #   buildr -R buildr/path -p deep/down/project clean compile api/install
  #
  # You can do for example, to invoke the compile target on subproj:
  #
  #   buildr -R buildr/path some/very/nested/subproj/compile
  # 
  # Or invoke a filetask by its path:
  # 
  #   buildr -R buildr/path ./api/target/api-1.0.0.jar
  #
  module PathArgs
    
    Buildr.application.iface.add_option '--directory DIR', '-C', 
    'Change to DIR before doing anything.', 
    'DIR must be a path' do |value|
      value = File.expand_path(value, original_dir)
      raise ArgumentError, "Not a directory: #{value}" unless File.directory?(value)
      options.requested_workdir = value
    end

    Buildr.application.iface.add_option '--project PROJECT', '-p',
    'Set project as the default target', 'instead of the top-level project' do |value|
      options.requested_workproj = value
    end

    # Lookup for a task using the given task_name.
    # This method extends Rake's functionality to obtain the task for a file path
    # or the build task if given a project basedir.
    def lookup(task_name, initial_scope=nil) #nodoc:
      unless task = super
        original = File.expand_path(options.requested_workdir || '', original_dir)
        path = File.expand_path(task_name, original)
        if !(task = @tasks[path]) && project = Buildr::Project.local_projects(path).first
          project_path = project.path_to(nil)
          if project_path == path
            task = @tasks[project.name + ':build']
          else
            project_task = path.sub(/^#{project_path}\/?/, '').gsub('/',':')
            task = @tasks[project.name + ':' + project_task] || @tasks[project_task]
          end
        end
      end
      task
    end

  private

    def find_buildfile #:nodoc:
      path = File.expand_path(options.requested_workdir || '', original_dir)
      Dir.chdir(@original_dir = options.requested_workdir = path) if File.directory?(path)
      super
    end

    def top_level #:nodoc:
      if options.requested_workproj
        path = File.expand_path(options.requested_workproj, original_dir)
        if File.directory?(path)
          project = Buildr::Project.local_projects(options.requested_workproj).first
        else
          project_name = options.requested_workproj.gsub(File::SEPARATOR, ':')
          project = Buildr.project(project_name)
        end
        path = project.path_to(nil)
        Dir.chdir(@original_dir = path)
      end
      super
    end
    
  end # PathArgs
  
  Buildr.application.extend PathArgs
  
end


