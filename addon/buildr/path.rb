# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements. See the NOTICE file distributed with this
# work for additional information regarding copyright ownership. The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

module Buildr

  # This Addon extends Buildr with a -C command line option like `make', `tar'
  # and other unix programs have and with a -p command line option to define a project
  #
  #
  # == Usage:
  # buildr -R buildr/path --help
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
  # buildr deep:down:project:clean deep:down:project:compile deep:down:project:api:install
  #
  # you can do
  #
  # buildr -R buildr/path -p deep/down/project clean compile api/install
  #
  # You can do for example, to invoke the compile target on subproj:
  #
  # buildr -R buildr/path some/very/nested/subproj/compile
  #
  # Or invoke a filetask by its path:
  #
  # buildr -R buildr/path ./api/target/api-1.0.0.jar
  #
  # === TIP: Make your buildfile executable.
  #
  # If you always want to use path-like arguments for your project, you may want to edit your buildfile like:
  #
  # #!/usr/bin/env ruby
  # exit !!eval(DATA.read) if $0 == __FILE__ # run buildr unless included
  #
  # # all your buildfile project definitions go here
  #
  # __END__
  # require 'rubygems'
  # require 'buildr'
  # require 'buildr/path' # load this addon
  # Buildr.application.run(ARGV)
  #
  # Then just make it executable..
  # chmod 755 buildfile
  # And run it
  # ./buildfile -p deep/down/project clean compile api/install
  module PathArgs
    attr_reader :launch_dir

    def standard_buildr_options
      super +
        [
          ['--directory', '-C DIR', 'Change to DIR before doing anything.',
            lambda { |value|
              value = File.expand_path(value, original_dir)
              raise ArgumentError, "Not a directory: #{value}" unless File.directory?(value)
              options.requested_workdir = value
            }
          ],
          ['--project', '-p PROJECT', 'Set project as the local project.',
            lambda { |value|
              raise ArgumentError, "Not a directory: #{value}" if value.include?(File::SEPARATOR) and not File.directory?(value)
              options.requested_workproj = value
            }
          ]
        ]
    end

     # ITTAY: using this increases run time by a large factor (30%). another alternative is to cache the tasks
#    # Lookup for a task using the given task_name.
#    # This method extends Rake's functionality to obtain the task for a file path
#    # or the build task if given a project basedir.
#    def lookup(task_name, initial_scope=nil) #nodoc:
#      unless task = super
#        original = File.expand_path(options.requested_workdir || '', original_dir)
#        path = File.expand_path(task_name, original)
#        if !(task = @tasks[path]) && project = Buildr::Project.local_projects(path).first
#          project_path = project.path_to(nil)
#          if project_path == path
#            task = @tasks[project.name + ':build']
#          else
#            project_task = path.sub(/^#{project_path}\/?/, '').gsub('/',':')
#            task = @tasks[project.name + ':' + project_task] || @tasks[project_task]
#          end
#        end
#      end
#      task
#    end

    def top_level #:nodoc:
      if options.requested_workproj
        @launch_dir = original_dir
        project = Project.resolve_project(options.requested_workproj)
        path = project.path_to(nil)
        Dir.chdir(@original_dir = path) if File.directory? path
      end
      super
    end


  private

    def find_buildfile #:nodoc:
      path = File.expand_path(options.requested_workdir || '', original_dir)
      Dir.chdir(@original_dir = options.requested_workdir = path) if File.directory?(path)
      super
    end

  end # PathArgs

  Buildr.application.extend PathArgs

  class Project
    class << self
      def resolve_project(path_or_name)
        path = File.expand_path(path_or_name, Buildr.application.launch_dir)
        if File.directory?(path)
          local_projects(path).sort{|p1, p2| p1.name.length <=> p2.name.length}.first
        else
          project_name = path_or_name.gsub(/\\|\//, ':')
          Buildr.project(project_name)
        end
      end
 
      alias_method :path_local_projects_original, :local_projects
      def local_projects(dir = nil, &block) #:nodoc:
        if dir.nil? && Buildr.application.options.requested_workproj 
          project = resolve_project(Buildr.application.options.requested_workproj)
          block[project]
        else
          path_local_projects_original(dir, &block)
        end        
      end
      
    end
    
  end  
end
