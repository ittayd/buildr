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


require 'rbconfig'
require 'pathname'
require 'builder' # A different kind of buildr, one we use to create XML.


module Buildr
  
  module Util
    extend self

    def java_platform?
      RUBY_PLATFORM =~ /java/
    end

    # In order to determine if we are running on a windows OS,
    # prefer this function instead of using Gem.win_platform?.
    #
    # Gem.win_platform? only checks the RUBY_PLATFORM global,
    # that in some cases like when running on JRuby is not 
    # succifient for our purpose:
    #
    # For JRuby, the value for RUBY_PLATFORM will always be 'java'
    # That's why this function checks on Config::CONFIG['host_os']
    def win_os?
      Config::CONFIG['host_os'] =~ /windows|cygwin|bccwin|cygwin|djgpp|mingw|mswin|wince/i
    end

    # Runs Ruby with these command line arguments.  The last argument may be a hash,
    # supporting the following keys:
    #   :command  -- Runs the specified script (e.g., :command=>'gem')
    #   :sudo     -- Run as sudo on operating systems that require it.
    #   :verbose  -- Override Rake's verbose flag.
    def ruby(*args)
      options = Hash === args.last ? args.pop : {}
      cmd = []
      ruby_bin = File.expand_path(Config::CONFIG['ruby_install_name'], Config::CONFIG['bindir'])
      if options.delete(:sudo) && !(win_os? || Process.uid == File.stat(ruby_bin).uid)
        cmd << 'sudo' << '-u' << "##{File.stat(ruby_bin).uid}"
      end
      cmd << ruby_bin
      cmd << '-S' << options.delete(:command) if options[:command]
      sh *cmd.push(*args.flatten).push(options) do |ok, status|
        ok or fail "Command failed with status (#{status ? status.exitstatus : 'unknown'}): [#{cmd.join(" ")}]"
      end
    end

    # Just like File.expand_path, but for windows systems it
    # capitalizes the drive name and ensures backslashes are used
    def normalize_path(path, *dirs)
      path = File.expand_path(path, *dirs)
      if win_os?
        path.gsub!('/', '\\').gsub!(/^[a-zA-Z]+:/) { |s| s.upcase }
      else
        path
      end
    end
    
    # Return the timestamp of file, without having to create a file task
    def timestamp(file)
      if File.exist?(file)
        File.mtime(file)
      else
        Rake::EARLY
      end
    end

    # Return the path to the first argument, starting from the path provided by the
    # second argument.
    #
    # For example:
    #   relative_path('foo/bar', 'foo')
    #   => 'bar'
    #   relative_path('foo/bar', 'baz')
    #   => '../foo/bar'
    #   relative_path('foo/bar')
    #   => 'foo/bar'
    #   relative_path('/foo/bar', 'baz')
    #   => '/foo/bar'
    def relative_path(to, from = '.')
      to = Pathname.new(to).cleanpath
      return to.to_s if from.nil?
      to_path = Pathname.new(File.expand_path(to.to_s, "/"))
      from_path = Pathname.new(File.expand_path(from.to_s, "/"))
      to_path.relative_path_from(from_path).to_s
    end

    # Search for a file starting from +dir+ and seeking on the parent
    # directories unless nosearch
    def find_file_updir(dir, names, nosearch = false)
      here = dir
      locate_rakefile = lambda { Dir['{'+names.map{ |rf| File.expand_path(rf, here) }.join(',')+'}'].first }
      until (found = locate_rakefile.call) || nosearch
        break if File.dirname(here) == here
        here = File.dirname(here)
      end
      found
    end

    # Generally speaking, it's not a good idea to operate on dot files (files starting with dot).
    # These are considered invisible files (.svn, .hg, .irbrc, etc).  Dir.glob/FileList ignore them
    # on purpose.  There are few cases where we do have to work with them (filter, zip), a better
    # solution is welcome, maybe being more explicit with include.  For now, this will do.
    def recursive_with_dot_files(*dirs)
      FileList[dirs.map { |dir| File.join(dir, '/**/{*,.*}') }].reject { |file| File.basename(file) =~ /^[.]{1,2}$/ }
    end

    # Utility methods for running gem commands
    module Gems
      extend self

      # Install gems specified by each Gem::Dependency if they are missing. This method prompts the user
      # for permission before installing anything.
      # 
      # Returns the installed Gem::Dependency objects or fails if permission not granted or when buildr
      # is not running interactively (on a tty)
      def install(*dependencies)
        raise ArgumentError, "Expected at least one argument" if dependencies.empty?
        remote = dependencies.map { |dep| Gem::SourceInfoCache.search(dep).last || dep }
        not_found_deps, to_install = remote.partition { |gem| gem.is_a?(Gem::Dependency) }
        fail Gem::LoadError, "Build requires the gems #{not_found_deps.join(', ')}, which cannot be found in local or remote repository." unless not_found_deps.empty?
        uses = "This build requires the gems #{to_install.map(&:full_name).join(', ')}:"
        fail Gem::LoadError, "#{uses} to install, run Buildr interactively." unless $stdout.isatty
        unless agree("#{uses} do you want me to install them? [Y/n]", true)
          fail Gem::LoadError, 'Cannot build without these gems.'
        end
        to_install.each do |spec|
          say "Installing #{spec.full_name} ... " if verbose
          command 'install', spec.name, '-v', spec.version.to_s, :verbose => false
          Gem.source_index.load_gems_in Gem::SourceIndex.installed_spec_directories
        end
        to_install
      end

      # Execute a GemRunner command
      def command(cmd, *args)
        options = Hash === args.last ? args.pop : {}
        gem_home = ENV['GEM_HOME'] || Gem.path.find { |f| File.writable?(f) }
        options[:sudo] = :root unless Util.win_os? || gem_home
        options[:command] = 'gem'
        args << options
        args.unshift '-i', gem_home if cmd == 'install' && gem_home && !args.any?{ |a| a[/-i|--install-dir/] }
        Util.ruby cmd, *args
      end

    end # Gems

  end # Util

  # Helper for lazy method application.
  class Message < Struct.new(:name, :args, :block) # :nodoc:
    def send_to(object)
      object.send(name, *args, &block)
    end
    def to_proc
      lambda { |object| send_to(object) }
    end
  end
  
  class MessageChain #:nodoc:
    attr_accessor :messages
    
    def method_missing(name, *args, &block)
      (@messages ||= []) << Message.new(name, args, &block)
    end
    
    def run(object, &block)
      if block
        messages.inject { |msg| yield msg.send_to(object) }
      else
        messages.inject { |msg| msg.send_to(object) }
      end
    end
  end

end # Buildr

