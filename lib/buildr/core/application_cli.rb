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

module Buildr

  # This class provides methods for command line interaction.
  # Handles command line arguments parsing.
  class CommandLineInterface
    
    attr_reader :app, :argv, :extra_argv
    
    def initialize(app)
      @app = app
      @argv = []
      @extra_argv = []
      @defs = []
    end

    # Add a CLI option
    # A Block must be supplied, when the option is matched, the block will be evaluated
    # on the application context
    #
    # This method should be called before parsing options
    def add_option(*args, &block)
      @defs << Message.new(:on, args, app_context(&block))
    end

    # Delete a CLI option matching regex
    #
    # This method should be called before parsing options
    def del_option(regex)
      @defs.delete_if { |msg| msg.args.any? { |a| regex === a } }
    end

    # Add an option to the tail
    def tail_option(*args, &block)
      @defs << Message.new(:on_tail, args, app_context(&block))
    end

    # Parse the given arguments array
    def parse_options(argv)
      argv = argv.dup
      if idx = argv.index('--')
        @extra_argv = argv[idx+1..-1]
        argv = argv[0...idx]
      end
      while idx = (argv.index('-R') || argv.index('--require-early'))
        raise "missing argument: --require-early" unless val = argv[idx+1]
        argv[idx,2] = []
        app.instance_eval { require val }
      end
      @argv = options_parser.parse(argv)
    end

    # Return the program usage string
    def usage
      @parser.banner
    end

    # Return the program options string
    def help
      @parser.to_s
    end

  private

    def app_context(&block)
      raise ArgumentError, "Expected block to be given" unless block
      lambda { |*args| app.instance_exec(*args, &block) }
    end

    def options_parser
      app.options.rakelib = ['rakelib']
      parser = OptionParser.new
      parser.banner = "buildr  [options] [tasks] [name=value]"
      parser.separator ""
      parser.separator "Options:"
      setup_buildr_options(parser)
      @defs.each { |msg| msg.send_to(parser) }
      @parser = parser
    end

    def setup_buildr_options(parser)
      buildr_standard_options.each { |args| parser.on(*args) }
      parser.on_tail('--require-early', '-R MODULE', 'Require MODULE on the bootstrap process.') do |value|
        fail "Late to require #{value}"
      end
      parser.on_tail("-h", "--help", "Display this help message.") do
        puts help
        exit
      end
      parser.on_tail('--', 'Stop processing command line.') do
        fail "Should not have been handled by now"
      end
    end

    # A list of all the standard options used in buildr, suitable for
    # passing to OptionParser.
    def buildr_standard_options
      [ # Buildr options
       ['--buildfile', '-f FILE', 
        'Use FILE as the buildfile',
        app_context { |file|
          rakefiles.clear
          rakefiles << file
        }
       ],
       ['--environment', '-e NAME', 
        'Environment name (e.g. development, test, production).',
        app_context { |name| ENV['BUILDR_ENV'] = @environment = name }
       ],
       ['--no-search', '--nosearch', '-n', "Do not search parent directories for the Rakefile.",
        app_context { |value| options.nosearch = true }
       ],
       ['--prereqs', '-P', 
        "Display the tasks and dependencies, then exit.",
        app_context { |value|
          options.show_prereqs = true
          options.show_task_pattern = Regexp.new(value || '.')
        }
       ],
       ['--quiet', '-q', 
        "Do not log messages to standard output.",
        app_context { |value| verbose(false) }
       ],
       ['--require', '-r MODULE', 
        "Require MODULE before executing buildfile.",
        app_context { |value| requires << value }
       ],
       ['--trace', '-t', "Turn on invoke/execute tracing, enable full backtrace.",
        app_context { |value|
          options.trace = true
          verbose(true)
        }
       ],
       ['--version', '-v', "Display the program version.",
        app_context { |value|
          puts version
          exit
        }
       ],
      ]
     end
    
  end # CommandLineInterface
  
end
