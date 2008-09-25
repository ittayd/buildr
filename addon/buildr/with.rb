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

  def with_option(*args, &block)
    WithOption.add(*args, &block)
  end

  # This Addon extends Buildr to add custom command line argument options
  # for example the --with-feature, --without-feature used by `make' tools.
  # loaded from a yaml file. It also serves as an example for --require-early option.
  #
  # == Usage
  #
  #   buildr -R buildr/with --help
  #
  # If you find this addon useful, make sure to read the TIP at end of this doc.
  # 
  # Note: Because this file extends Buildr command line arguments, it needs to be loaded during 
  #       the bootstrap process (Prior to parsing the command line). 
  #       So it needs to be loaded using the --require-early (-R) option.
  #
  # By default this addon searches a file named with.yml (actually any on FILES).
  # This yaml is a simple hash:
  #
  #   ## with.yml ##
  #     \:foo: sure                # --with-foo, --without-foo  (default: 'sure')
  #     --[no-]thanks: false      # --thanks and --no-thanks flags (default: false)
  #     bar: 99BottlesOfBeer      # --bar flag
  #     -s [VALUE]: GreenEyes     # -s flag with optional argument (default: 'GreenEyes')
  #
  #     # Using custom descriptions:
  #     custom: 
  #       positive: load user customization     # description for enabled flag
  #       negative: Use generic settings        # description for disabled flag
  #       default: false
  #
  #     --[no-]pain:                            # use the option as is
  #       description: "Call the doctor!"
  #       default: false
  #
  #     -N, --name NAME:                        # use option as is
  #       description: 'Set my name'
  #       default: Lael
  #
  #  Running 
  #    buildr -R buildr/with --help 
  #  will display in addition to Buildr standard options:
  #
  #    -N, --name NAME                  Set my name
  #        --[no-]pain                  Call the doctor!
  #    -s [VALUE]                       Enable s
  #        --with-bar                   Enable bar
  #        --without-bar                Disable bar
  #        --with-custom                load user customization
  #        --without-custom             Use generic settings
  #        --[no-]thanks                Enable thanks
  #        --with-foo                   Enable foo
  #        --without-foo                Disable foo
  #      
  #
  # You can access the values on your buildfile using 
  #   Buildr.application.with
  #
  #   ## buildfile ##
  #   puts "Features are: ", Buildr.application.with.inspect
  #   if Buildr.application.with.thanks
  #     describe('thanks-project') do
  #        package(:jar) # etc
  #     end
  #   else
  #     info "You can thank me later"
  #   end
  # 
  # If you want to prevent this addon from seeking a yaml file, because you want to manually
  # setup the features, you need to create a ruby file, say .. with.rb having 
  #
  #   ## with.rb ##
  #      module Buildr::WithOption
  #         @dont_seek_yaml_files = true # set nil to disable seeking or set to an array of file names to search
  #         # override the :setter method to return a lambda to set values on
  #         # a different object than the default: Buildr.application.with
  #      end
  #      require 'buildr/with'
  #      # You can manually setup your features here..
  #      Buildr.with_option(:moo, "Use cows", "Use pigs") do |value|
  #         # set the value somewhere accessible from the buildfile
  #      end
  #
  # Then load with.rb instead of buildr/with.rb:  
  #
  #   buildr -R with
  #
  #
  # === TIP: Make your buildfile executable 
  # 
  # To avoid typing -R each time, you can make your buildfile executable, just edit it like this:
  #
  #   #!/usr/bin/env ruby
  #   exit !!eval(DATA.read) if $0 == __FILE__ # run buildr unless included
  #
  #
  #   # all your buildfile project definitions go here
  #   define('foo') do 
  #      define('bar') do
  #        puts "Defined because you enabled it with command line option"
  #      end if Buildr.application.with.bar
  #   end
  #
  #   
  #   __END__
  #   require 'rubygems'
  #   require 'buildr'
  #   require 'buildr/with' # load this addon
  #   with_option '--[no-]bar', 'Enable bar', 'Disable bar', false
  #   Buildr.application.run(ARGV)
  #
  # Then just make it executable..
  #   chmod 755 buildfile 
  # And run it
  #   ./buildfile --bar
  module WithOption
    extend self

    # The yaml file names searched by this addon
    unless const_defined?(:FILES)
      FILES = %w[ with.yml with.yaml ]
    end

    # Register a new feature option
    def add(flags, positive = nil, negative = nil, default = nil, &block)
      flag_name = lambda { |str| (str[/^-(-?(\[no\-\])?)?([\w-]+)/] ? $3 : str).to_s.gsub('-', '_') }
      if Array === flags
        property = flags.map(&:to_s).map(&flag_name).sort.max
      elsif flags.to_s[/\s*,\s*/]
        flags = flags.to_s.split(/\s*,\s*/).map{ |s| s.strip }
        property = flags.map(&flag_name).sort.max
      else
        property = flag_name[flags = flags.to_s]
      end
      positive ||= "Enable #{property}"
      negative ||= "Disable #{property}"
      block ||= setter(property)
      block[default]
      if Array === flags || flags.to_s[/^-/] || positive == negative
        args = [positive]
        if Array === flags
          args.unshift(*flags)
        else
          args.unshift(flags[/^-/] ? flags : '--' + flags)
        end
        Buildr.application.iface.add_option(*args, &block)
      else
        Buildr.application.iface.add_option("--with-#{property}", positive) { instance_exec(true, &block) }
        Buildr.application.iface.add_option("--without-#{property}", negative) { instance_exec(false, &block) }
      end
    end

    # Load --with-feature definitions from the yaml in path
    def from_yaml(path)
      require 'yaml'
      hash = YAML.load(File.read(path))
      raise "Expected #{path} to be a Hash of features" unless Hash === hash
      hash.each_pair do |flag, value|
        positive, negative = nil, nil
        if Hash === value
          positive = value[:positive] || value['positive'] || value[:description] || value['description']
          negative = value[:negative] || value['negative']
          value = value[:default] || value['default'] || value[:value] || value['value']
        end
        add(flag, positive, negative, value)
      end
    end

  protected
    
    # Return a lambda for setting property
    # Override this method to set values on other than Buildr.application.with
    def setter(property)
      lambda do |value| 
        Buildr.application.with ||= OpenStruct.new
        Buildr.application.with.send("#{property}=", value)
      end
    end unless method_defined?(:setter)
    
    def find_file(names, options = {})
      here = options[:from] || Dir.pwd
      upto = options[:upto] || File.expand_path('/')
      locate = lambda { Dir['{'+names.map{ |f| File.expand_path(f, here) }.join(',')+'}'].first }
      found = nil
      until (found = locate.call)
        break if File.dirname(here) == here || (upto && upto == here)
        here = File.dirname(here)
      end
      found
    end

    def seek_yaml_files(files)
      return if !files.kind_of?(Array) || files.empty? || @dont_seek_yaml_files
      rakefile = find_file(Buildr.application.send(:rakefiles))
      if rakefile
        yaml = find_file(files, :upto => File.dirname(rakefile))
        trace "Loading features from yaml file #{yaml}"
        from_yaml yaml if yaml
      end
    end
    
    seek_yaml_files(FILES) if const_defined?(:FILES) && !@dont_seek_yaml_files

    unless Buildr.application.respond_to?(:with)
      def (Buildr.application).with
        @with ||= OpenStruct.new
      end 
    end
    
  end # WithOption

end

