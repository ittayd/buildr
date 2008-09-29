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
    def to_proc
      lambda { |object| send_to(object) }
    end
  end

  class MessageChain < BasicObject #:nodoc:
    def messages
      @messages ||= []
    end

    def method_missing(name, *args, &block)
      messages << Message.new(name, args, &block)
    end
    
    def send_to(object, &block)
      messages.map { |msg| block ? block.call(msg.send_to(object)) : msg.send_to(object) }
    end

    def to_proc
      lambda { |object| send_to(object) }
    end
  end
  
  # This class helps to create advices before/after/around already existing methods.
  class Advice
    
    class << self
      
      def before(*args, &block)
        register(Before, caller.first.split(':')[0,2].join(':'), *args, &block)
      end
      
      def after(*args, &block)
        register(After, caller.first.split(':')[0,2].join(':'), *args, &block)
      end
      
      def around(*args, &block)
        register(Around, caller.first.split(':')[0,2].join(':'), *args, &block)
      end
      
      def instances
        @instances ||= {}
      end

    private

      def register(type, location, target, message_name, on_singleton = false, &block) #:nodoc:
        time = Time.now
        target = class << target; self; end if on_singleton
        meth = target.instance_method(message_name)
        advice_name = [nil, type.name, target.object_id, time.to_i, time.usec, location]
        advice_name = advice_name.join('__').intern
        advice = Advice.new(advice_name, type, &block)
        instances[advice_name] = advice
        target.module_eval <<-RUBY
          alias_method :'#{advice_name}', :'#{message_name}'
          def #{message_name}(*args, &block)
            Advice.instances[:'#{advice_name}'].run(self, Message.new(:'#{message_name}', args, block))
          end
        RUBY
        advice
      end
    end

    module Before
      def execute
        @result = block.call(self) if block
        chain.send_to(target) { |res| @result = res }
        @result = target.send(name, *message.args, &message.block)
      end
    end
    
    module After
      def execute
        @result = target.send(name, *message.args, &message.block)
        @result = block.call(self) if block
        chain.send_to(target) { |res| @result = res }
        @result
      end
    end

    module Around
      def continue
        @result = target.send(name, *message.args, &message.block)
      end
      
      def execute
        @result = block.call(self) if block
        chain.send_to(target) { |res| @result = res }
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
    
    def run(target, message) #:nodoc:
      catch(name) { Advice.new(name, advice_type, target, message, chain, &block).execute }
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

  end

end
