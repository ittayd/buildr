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

require 'rake'

module Rake #:nodoc
  
  def self.application
    # don't create a rake app by default
    (ctx = Buildr::Context.current) ? ctx.application : @application
  end

  class Task #:nodoc:
    def invoke(*args)
      task_args = TaskArguments.new(arg_names, args)
      invoke_with_call_chain(task_args, Thread.current[:rake_chain] || InvocationChain::EMPTY)
    end

    def invoke_with_call_chain(task_args, invocation_chain)
      new_chain = InvocationChain.append(self, invocation_chain)
      @lock.synchronize do
        if application.options.trace
          puts "** Invoke #{name} #{format_trace_flags}"
        end
        return if @already_invoked
        @already_invoked = true
        begin
          invoke_prerequisites(task_args, new_chain)
        rescue
          trace "Exception while invoking prerequisites of task #{self.inspect}"
          raise
        end
        begin
          old_chain, Thread.current[:rake_chain] = Thread.current[:rake_chain], new_chain
          execute(task_args) if needed?
        ensure
          Thread.current[:rake_chain] = nil
        end
      end
    end
  end # Task

  # Top level Rake methods
  module RakeMethods #:nodoc:
    [ :task, :file, :file_create, :directory,
      :multitask, :namespace, :rule, :desc, :import 
    ].each { |n| define_method n, Object.instance_method(n) }
      
    def self.remove_from(mod)
      instance_methods(false).each { |n| mod.send :remove_method, n }
    end
  end # RakeMethods

end # Rake

module Buildr #:nodoc:

  module RakeMethods

    rake_methods = Object.new.extend Rake::RakeMethods
    Message.define(self, Rake::RakeMethods.instance_methods(false)) do |obj, msg|
      Application.apply_or_defer { msg.call rake_methods }
    end
    
  end # RakeMethods

end # Buildr

class Object #:nodoc:
  Rake::RakeMethods.remove_from(self)
  include Buildr::RakeMethods
end
