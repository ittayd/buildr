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
  
  # Helper for lazy method application.
  class Message < Struct.new(:name, :args, :block) # :nodoc:

    def send_to(object)
      object.send(name, *args, &block)
    end

    alias_method :call, :send_to
    
    def to_proc
      lambda { |object| send_to(object) }
    end

  end

  class MessageChain < BasicObject #:nodoc:

    def messages
      @messages ||= []
    end

    def <<(callable)
      raise "Expected #{callable} to respond to :call" unless callable.respond_to?(:call)
      messages << callable
    end

    def method_missing(name, *args, &block)
      messages << Message.new(name, args, block)
      self
    end
    
    def send_to(object, &block)
      messages.map { |msg| block ? block.call(msg.call(object)) : msg.call(object) }
    end

    alias_method :call, :send_to

    def to_proc
      lambda { |object| send_to(object) }
    end

  end
  
  # This class helps to create advices before/after/around already existing methods.
  class Advice
    
    class << self
      
      # Define a before advice for a message on a given module
      def before(target_module, message_name, &block)
        register(Before, target_module, message_name, &block)
      end
      
      # Define an after advice for a message on a given module
      def after(target_module, message_name, &block)
        register(After, target_module, message_name, &block)
      end
      
      # Define an around advice for a message on a given module
      def around(target_module, message_name, &block)
        register(Around, target_module, message_name, &block)
      end

      # Define a before advice on the metaclass of target_instance for message
      def before!(target_instance, message_name, &block)
        register(Before, class << target_instance; self; end, message_name, &block)
      end
      
      # Define an after advice on the metaclass of target_instance for message
      def after!(target_instance, message_name, &block)
        register(After, class << target_instance; self; end, message_name, &block)
      end
      
      # Define an around advice on the metaclass of target_instance for message
      def around!(target_instance, message_name, &block)
        register(Around, class << target_instance; self; end, message_name, &block)
      end
      
      def instances
        @instances ||= {}
      end

    private

      def register(type, target, message_name, &block) #:nodoc:
        time = Time.now
        meth = target.instance_method(message_name)
        location = caller[1].split(':')[0,2].join(':')
        advice_name = [nil, type.name, target.object_id, time.to_i, time.usec, location]
        advice_name = advice_name.join('__').intern
        advice = Advice.new(advice_name, type, target, message_name, &block)
        instances[advice_name] = advice
        target.module_eval <<-RUBY
          alias_method :'#{advice_name}', :'#{message_name}'
          def #{message_name}(*args, &block)
            Advice.instances[:'#{advice_name}'].run(self, *args, &block)
          end
        RUBY
        advice
      end
    end

    module Before
      def execute
        run_hooks
        continue
        @result
      end
    end
    
    module After
      def execute
        continue
        run_hooks
        @result
      end
    end

    module Around
      def execute
        run_hooks
        @result
      end
    end

    attr_reader :name, :advice_type, :message, :chain, :block, :target, :result
    
    def initialize(name, advice_type, target = nil, message = nil, chain = nil, &block) #:nodoc:
      extend advice_type
      @name, @advice_type = name, advice_type
      @target, @message = target, message
      @chain = chain || MessageChain.new
      @block = block
    end
    
    def return(value = result)
      throw @name, value
    end
    
    def run(target, *args, &proc) #:nodoc:
      catch(name) { Advice.new(name, advice_type, target, Message.new(message, args, proc), chain, &block).execute }
    end
    
    def before?
      Before === self
    end
    
    def after?
      After === self
    end
    
    def around?
      Around === self
    end

    def run_hooks
      @result = block.call(self) if block
      chain.send_to(target) { |res| @result = res }
    end

    def continue(args = nil, &block)
      args ||= message.args
      block ||= message.block
      @result = target.send(name, *args, &block) if message && message.name
    end

  end

end
