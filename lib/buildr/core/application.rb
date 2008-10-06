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

# Portion of this file derived from Rake.
# Copyright (c) 2003, 2004 Jim Weirich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'highline/import'

# Gem::user_home is nice, but ENV['HOME'] lets you override from the environment.
ENV["HOME"] ||= File.expand_path(Gem::user_home)
ENV['BUILDR_ENV'] ||= 'development'


module Buildr

  # Provide settings that come from three sources.
  #
  # User settings are placed in the .buildr/settings.yaml file located in the user's home directory.
  # They should only be used for settings that are specific to the user and applied the same way
  # across all builds.  Example for user settings are preferred repositories, path to local repository,
  # user/name password for uploading to remote repository.
  #
  # Build settings are placed in the build.yaml file located in the build directory.  They help keep
  # the buildfile and build.yaml file simple and readable, working to the advantages of each one.
  # Example for build settings are gems, repositories and artifacts used by that build.
  #
  # Profile settings are placed in the profiles.yaml file located in the build directory.  They provide
  # settings that differ in each environment the build runs in.  For example, URLs and database
  # connections will be different when used in development, test and production environments.
  # The settings for the current environment are obtained by calling #profile.
  class Settings

    def initialize(application) #:nodoc:
      @application = application
      @user = load_from('settings', @application.home_dir)
      @build = load_from('build')
      @profiles = load_from('profiles')
    end

    # User settings loaded from setting.yaml file in user's home directory.
    attr_reader :user

    # Build settings loaded from build.yaml file in build directory.
    attr_reader :build

    # Profiles loaded from profiles.yaml file in build directory.
    attr_reader :profiles

    # :call-seq:
    #    profile => hash
    #
    # Returns the profile for the current environment.
    def profile
      profiles[@application.environment] ||= {}
    end

  private

    def load_from(base_name, dir = nil)
      dir ||= @application.original_dir
      base_name = File.expand_path(base_name, dir)
      file_name = ['yaml', 'yml'].map { |ext| "#{base_name}.#{ext}" }.find { |fn| File.exist?(fn) }
      return {} unless file_name
      yaml = YAML.load(File.read(file_name)) || {}
      fail "Expecting #{file_name} to be a map (name: value)!" unless Hash === yaml
      @application.buildfile.enhance [file_name]
      yaml
    end

  end # Settings

  # This task stands for the buildfile and all its associated helper files (e.g., buildr.rb, build.yaml).
  # By using this task as a prerequisite for other tasks, you can ensure these tasks will be needed
  # whenever the buildfile changes.
  class BuildfileTask < Rake::FileTask
    def timestamp
      ([name] + prerequisites).map { |f| File.stat(f).mtime }.max rescue Time.now
    end
  end

  class Application < Rake::Application #:nodoc:
    
    # This message chain is run only once after buildr has been loaded
    # Adding messages after that will execute them inmediatly.
    extend MessageChain.collector(:@boot) {
      buildr_loaded = false
      loaded = lambda { buildr_loaded = true }
      MessageChain.new(nil, loaded) do |child|
        # If buildr has already loaded, clean the chain & execute child
        if buildr_loaded
          chain.messages.replace []
          child.return child.call(self)
        end
      end
    }
    
    # Create a default application when everything is ready
    boot { Buildr.application = Application.new }
    
    # This message chain is run for every application as part of
    # their initialization process (Application#init)
    #
    # If a message is added to this chain and we also have a current
    # application, then the message is applied to it.
    extend MessageChain.collector(:@init) {
      MessageChain.new do |child|
        # Execute inmediatly if we have a current application
        ctx = Context.current and child.return child.call(ctx.application)
      end
    }

    class << self
      
      # Apply the given messages to the currently running application
      # or if no current application, defer until Application#init
      def apply_or_defer(*messages, &block)
        Application.init *messages, &block
      end
      
    end
    
    DEFAULT_BUILDFILES = ['buildfile', 'Buildfile'] + DEFAULT_RAKEFILES
    
    attr_reader :rakefiles, :requires
    private :rakefiles, :requires

    def initialize
      super
      @rakefiles = DEFAULT_BUILDFILES
      @name = 'Buildr'
      @requires = []
      @top_level_tasks = []
      @home_dir = File.expand_path('.buildr', ENV['HOME'])
      mkpath @home_dir, :verbose=>false unless File.exist?(@home_dir)
      @environment = ENV['BUILDR_ENV'] ||= 'development'
      @on_completion = []
      @on_failure = []
    end

    # Returns list of Gems associated with this buildfile, as listed in build.yaml.
    # Each entry is of type Gem::Specification.
    attr_reader :gems

    # Buildr home directory, .buildr under user's home directory.
    attr_reader :home_dir

    # Copied from BUILD_ENV.
    attr_reader :environment

    # Returns the Settings associated with this build.
    def settings
      fail "Internal error: Called Buildr.settings before buildfile located" unless rakefile
      @settings ||= Settings.new(self)
    end

    # :call-seq:
    #   buildfile
    # Returns the buildfile as a task that you can use as a dependency.
    def buildfile
      @buildfile_task ||= BuildfileTask.define_task(File.expand_path(rakefile))
    end
    
    # Files that complement the buildfile itself
    def build_files #:nodoc:
      buildfile.prerequisites
    end

    def run(argv = ARGV)
      context do
        standard_exception_handling do
          init
          iface_init(argv)
          find_buildfile
          change_workdir
          load_gems
          load_artifacts
          load_tasks
          load_requires
          load_buildfile
          load_imports
          task('buildr:initialize').invoke
          top_level
        end
        title, message = 'Your build has completed', "#{Dir.pwd}\nbuildr #{@top_level_tasks.join(' ')}"
        @on_completion.each { |block| block.call(title, message) rescue nil }
      end
    end
    
    # Yields to block on successful completion. Primarily used for notifications.
    def on_completion(&block)
      @on_completion << block
    end

    # Yields to block on failure with exception. Primarily used for notifications.
    def on_failure(&block)
      @on_failure << block
    end

    # Not for external consumption.
    def switch_to_namespace(names) #:nodoc:
      current, @scope = @scope, names
      begin
        yield
      ensure
        @scope = current
      end
    end

    # :call-seq:
    #   deprecated(message)
    #
    # Use with deprecated methods and classes. This method automatically adds the file name and line number,
    # and the text 'Deprecated' before the message, and eliminated duplicate warnings. It only warns when
    # running in verbose mode.
    #
    # For example:
    #   deprecated 'Please use new_foo instead of foo.'
    def deprecated(message) #:nodoc:
      return unless verbose
      "#{caller[1]}: Deprecated: #{message}".tap do |message|
        @deprecated ||= {}
        unless @deprecated[message]
          @deprecated[message] = true
          warn message
        end
      end
    end

    # Return the application context
    def context(&block) #:nodoc:
      @context ||= Context.new(self)
      return @context unless block
      @context.execute(block)
    end

    # The user interface.
    # Currently Buildr only runs on command line
    def iface # :nodoc:
      @iface ||= CommandLineInterface.new(self)
    end

    # Return the version string
    def version #:nodoc:
      "Buildr #{Buildr::VERSION} #{RUBY_PLATFORM[/java/] && '(JRuby '+JRUBY_VERSION+')'}"
    end

  private

    def init #:nodoc:
      # set the current context as active
      Context.current = context
      # create tasks, extensions, etc.
      Application.init.call self
    end

    # Initialize from the application interface
    def iface_init(argv) #:nodoc:
      iface.parse_options(argv.clone)
      collect_tasks iface.argv # collect tasks from the parsed argv
    end
    
    # Collect the list of tasks on the command line.  If no tasks are
    # given, return a list containing only the default task.
    # Environmental assignments are processed at this time as well.
    #
    # Note: Buildr's version of this method upcases the environment
    # variables, thus it differs from Rake's impl.
    def collect_tasks(argv) #:nodoc:
      @top_level_tasks = []
      argv.each do |arg|
        if arg =~ /^(\w+)=(.*)$/
          ENV[$1.upcase] = $2
        else
          top_level_tasks << arg unless arg =~ /^-/
        end
      end
      top_level_tasks.push("default") if top_level_tasks.size == 0
    end

    # Returns Gem::Specification for every listed and installed Gem, Gem::Dependency
    # for listed and uninstalled Gem, which is the installed before loading the buildfile.
    def listed_gems #:nodoc:
      Array(settings.build['gems']).map do |dep|
        name, trail = dep.scan(/^\s*(\S*)\s*(.*)\s*$/).first
        versions = trail.scan(/[=><~!]{0,2}\s*[\d\.]+/)
        versions = ['>= 0'] if versions.empty?
        dep = Gem::Dependency.new(name, versions)
        Gem::SourceIndex.from_installed_gems.search(dep).last || dep
      end
    end

    # Load artifact specs from the build.yaml file, making them available 
    # by name ( ruby symbols ).
    def load_artifacts #:nodoc:
      hash = settings.build['artifacts']
      return unless hash
      raise "Expected 'artifacts' element to be a hash" unless Hash === hash
      # Currently we only use one artifact namespace to rule them all. (the root NS)
      Buildr::ArtifactNamespace.load(:root => hash)
    end
      
    # Load/install all Gems specified in build.yaml file.
    def load_gems #:nodoc:
      missing_deps, installed = listed_gems.partition { |gem| gem.is_a?(Gem::Dependency) }
      unless missing_deps.empty?
        newly_installed = Util::Gems.install(*missing_deps)
        installed += newly_installed
      end
      installed.each do |spec|
        if gem(spec.name, spec.version.to_s)
          # TODO: is this intended to load rake tasks from the installed gems?
          # We should use a convention like .. if the gem has a _buildr.rb file, load it.

          #FileList[spec.require_paths.map { |path| File.expand_path("#{path}/*.rb", spec.full_gem_path) }].
          #  map { |path| File.basename(path) }.each { |file| require file }
          #FileList[File.expand_path('tasks/*.rake', spec.full_gem_path)].each do |file|
          #  Buildr.application.add_import file
          #end
        end
      end
      @gems = installed
    end

    def find_buildfile #:nodoc:
      @rakefile = Util.find_file_updir(original_dir, rakefiles, options.nosearch) unless rakefile
      unless rakefile
        error = "No Buildfile found (looking for: #{rakefiles.join(', ')})"
        if STDIN.isatty
          Rake::Task['generate'].invoke
          exit 1
        else
          raise error
        end
      end
    end

    # Change the working directory unless we are currently there.
    def change_workdir(dir = nil, &block)
      dir ||= File.dirname(rakefile)
      if Dir.pwd == dir
        yield dir if block
      else
        Dir.chdir(dir, &block)
      end
    end

    def load_buildfile #:nodoc:
      info "(in #{Dir.pwd}, #{environment})"
      unless @rakefile.to_s.empty?
        path = File.expand_path(@rakefile)
        context.instance_eval File.read(path), path
      end
      buildfile.enhance @requires.select { |f| File.file?(f) }.map{ |f| File.expand_path(f) }
    end

    def load_requires #:nodoc:
      @requires.each { |name| require name }
    end

    # Loads buildr.rb files from users home directory and project directory.
    # Loads custom tasks from .rake files in tasks directory.
    def load_tasks #:nodoc:
      files = [ File.expand_path('buildr.rb', ENV['HOME']), 'buildr.rb' ].select { |file| File.exist?(file) }
      files += [ File.expand_path('buildr.rake', ENV['HOME']), File.expand_path('buildr.rake') ].
        select { |file| File.exist?(file) }.each { |file| warn "Please use '#{file.ext('rb')}' instead of '#{file}'" }
      #Load local tasks that can be used in the Buildfile.
      files += Dir[File.expand_path('tasks/*.rake')]
      files.each do |file|
        unless $LOADED_FEATURES.include?(file)
          load file
          $LOADED_FEATURES << file
        end
      end
      buildfile.enhance files
      true
    end

    def display_prerequisites
      invoke_task('buildr:initialize')
      tasks.each do |task|
        if task.name =~ options.show_task_pattern
          puts "buildr #{task.name}"
          task.prerequisites.each { |prereq| puts "    #{prereq}" }
        end
      end
    end
    
    # Provide standard execption handling for the given block.
    def standard_exception_handling
      begin
        yield
      rescue SystemExit => ex
        # Exit silently with current status
        exit(ex.status)
      rescue SystemExit, OptionParser::InvalidOption => ex
        # Exit silently
        exit(1)
      rescue Exception => ex
        title, message = 'Your build failed with an error', "#{Dir.pwd}:\n#{ex.message}"
        @on_failure.each { |block| block.call(title, message, ex) rescue nil }
        # Exit with error message
        $stderr.puts "buildr aborted!"
        $stderr.puts $terminal.color(ex.message, :red)
        if options.trace
          $stderr.puts ex.backtrace.join("\n")
        else
          $stderr.puts ex.backtrace.select { |str| str =~ /#{rakefile}/ }.map { |line| $terminal.color(line, :red) }.join("\n")
          $stderr.puts "(See full trace by running task with --trace)"
        end
        exit(1)
      end
    end

  end # Application

  # This module helps to create and run multiple Application instances, each of them
  # having a Context instance used evaluate the buildfile on it, so that constants 
  # defined on a buildfile doesn't collide with constants from other.
  # 
  # The current application being run is determined by 
  #   Context.current.application
  #
  # To avoid conflicting with other applications, instead of storing globals or
  # module instance variables, you can use the context as a state handler for each app.
  # See the documentation for the accessor method.
  class Context #:nodoc:
    include Buildr
    
    class << self
      attr_accessor :current

      # :call-seq:
      #   include Context.accessor(attr_name, reader = :public, writer = reader, default_value)
      #   include Context.accessor(attr_name, reader = :public, writer = reader) { DefaultValue.new }
      #  
      # Return a module with context sentitive accessor methods, values are accessed from
      # the current context object. 
      #
      # First argument is the attribute name to generate accessors for.
      # Second and third arguments are the visibility for the reader and writer methods respectively,
      # you can set any of them to false to skip generating the reader or writer method.
      # Third argument specifies the default attribute value, or if a block is given it will be called
      # the obtain the default value the first time the reader method is called.
      # 
      # The following example from the Buildr::Logger module, illustrates usage:
      #
      #   module Logger
      #     extend Context.accessor(:instance) { CommandLineInterface::Logger.new }
      #     Application.init { |app| Logger.instance = app.iface.logger }
      #   end
      #
      # The Logger.instance method will return the logger for the current application,
      # when a new application is initialized, its iface.logger is set for on application context.
      # This way applications can use different loggers, accessed by the same interface.
      def accessor(attribute, readable = :public, writable = readable, default_value = nil, &block) #:nodoc:
        writable = [:public, :protected, :private].include?(writable) ? writable : nil
        readable = [:public, :protected, :private].include?(readable) ? readable : nil
        raise ArgumentError, 'No valid visibility for reader and writer' unless readable || writable
        Module.new do |mod|
          Message.define(mod, attribute, readable) do |obj, msg|
            ctx = Context.current
            raise 'No current Buildr::Context' unless ctx
            ctx.state[[obj, attribute]] ||= default_value || block.call(obj, attribute)
          end if readable
          Message.define(mod, attribute.to_s + '=', writable) do |obj, msg|
            ctx = Context.current
            raise 'No current Buildr::Context' unless ctx
            ctx.state[[obj, attribute]] = msg.args.first
          end if writable
        end
      end
    end

    # The state holder for Context accessors
    attr_reader :state

    def initialize(app)
      @application = app
      @state = Hash.new
    end

    # Return the application for this context.
    # The currently running application can be obtained with
    #    Context.current.application
    def application
      @application
    end

    # TODO: replace with a thread safe version so that we can
    # execute several buildr instances at the same time
    def execute(block)
      old, Context.current = Context.current, self
      begin
        block.call(self)
      ensure
        Context.current = old
      end
    end

    def inspect #:nodoc:
      %Q{context(#{application})}
    end
    
  end # Context

  # Mixin for objects requiring log output
  #    include Buildr::Logger
  #    def some; trace('Trace this'); end
  # Or
  #    def some; Buildr::Logger.trace('Trace that'); end
  module Logger #:nodoc:
    extend self
    
    extend Context.accessor(:instance) { CommandLineInterface::Logger.new }
    Application.init { |app| Logger.instance = app.iface.logger }
      
    [ :warn_without_color, :warn, :error, :info, :trace ].each do |name|
      Message.define(self, name) { |obj, msg| msg.call Logger.instance }
    end

    # Add logging methods into the top level object.
    # I'd prefer to include Logger only on those needing it.
    # or having them to call methods on Buildr::Logger
    Application.boot do
      instance_methods(false).each do |name|
        eval("def #{name}(*a, &b); Buildr::Logger.#{name}(*a, &b); end", TOPLEVEL_BINDING)
      end
    end
  end # Logger

  class << self

    Application.init do
      task 'buildr:initialize' do
        # Is this method actually used?
        # Buildr.load_tasks_and_local_files
      end
    end

    # Returns the currently running Buildr::Application object.
    def application
      Rake.application
    end

    def application=(app) #:nodoc:
      Rake.application = app
    end

    # Returns the Settings associated with this build.
    def settings
      Buildr.application.settings
    end

    # Copied from BUILD_ENV.
    def environment
      Buildr.application.environment
    end

  end
  
end # Buildr

# Add a touch of color when available and running in terminal.
if $stdout.isatty
  begin
    require 'Win32/Console/ANSI' if Config::CONFIG['host_os'] =~ /mswin/
    HighLine.use_color = true
  rescue LoadError
  end
else
  HighLine.use_color = false
end


# Let's see if we can use Growl.  We do this at the very end, loading Ruby Cocoa
# could slow the build down, so later is better.  We only do this when running 
# from the console in verbose mode.
if $stdout.isatty && verbose && RUBY_PLATFORM =~ /darwin/
  begin
    require 'osx/cocoa'
    icon = OSX::NSApplication.sharedApplication.applicationIconImage
    icon = OSX::NSImage.alloc.initWithContentsOfFile(File.join(File.dirname(__FILE__), '../resources/buildr.icns'))

    # Register with Growl, that way you can turn notifications on/off from system preferences.
    OSX::NSDistributedNotificationCenter.defaultCenter.
      postNotificationName_object_userInfo_deliverImmediately(:GrowlApplicationRegistrationNotification, nil,
        { :ApplicationName=>'Buildr', :AllNotifications=>['Completed', 'Failed'], 
          :ApplicationIcon=>icon.TIFFRepresentation }, true)
    
    notify = lambda do |type, title, message|
      OSX::NSDistributedNotificationCenter.defaultCenter.
        postNotificationName_object_userInfo_deliverImmediately(:GrowlNotification, nil,
          { :ApplicationName=>'Buildr', :NotificationName=>type,
            :NotificationTitle=>title, :NotificationDescription=>message }, true)
    end
    Buildr::Application.init.on_completion { |title, message| notify['Completed', title, message] }
    Buildr::Application.init.on_failure { |title, message, ex| notify['Failed', title, message] }
  rescue Exception # No growl
  end
elsif $stdout.isatty && verbose
  notify = lambda { |type, title, message| $stdout.puts "[#{type}] #{title}: #{message}" }
  Buildr::Application.init.on_completion { |title, message| notify['Completed', title, message] }
  Buildr::Application.init.on_failure { |title, message, ex| notify['Failed', title, message] }
end
