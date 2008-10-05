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
  class Message # :nodoc:
    attr_accessor :name, :args, :block
    
    def initialize(name, args = nil, block = nil)
      @binding = lambda { }
      @name, @args, @block = name, args, block
    end

    # Apply this message on object
    def call(object)
      object.__send__(name, *args, &block)
    end

    def to_proc
      method(:call).to_proc
    end

    def inspect
      "#<#{self.class}@#{backtrace.first} #{name}(*#{args.inspect}, &#{block.inspect})>"
    end

    def backtrace(idx = 0)
      eval("caller(2 + #{idx})", @binding)
    end
        
    def to_s
      inspect
    end

    class << self
      
      # Define a method on module.
      # The implementation callback is yield the callee and the
      # received Message.
      def define(on_module, names, visibility = :public, &implementation)
        raise "Expected implementation block" unless implementation
        raise "Invalid visibility modifier: #{visibility}" unless 
          [:public, :protected, :private].include? visibility
        anon = Module.new do |anon|
          (class << anon; self end).module_eval { define_method(:message_impl, implementation) }
        end
        defined_from = caller.first
        on_module.extend anon
        Array(names).flatten.compact.each do |name|
          on_module.module_eval <<-RUBY, __FILE__, 1+__LINE__
            def #{name}(*args, &block)
              anon = ObjectSpace._id2ref(#{anon.object_id})
              anon.message_impl(self, Message.new(:'#{name}', args, block))
            end
            #{visibility} :#{name}
          RUBY
        end
      end

    end

  end # Message

  class MessageChain < BasicObject #:nodoc:
    attr_accessor :parent, :messages
    
    def initialize(parent = nil, *messages, &block)
      @parent, @messages, @when_added = parent, messages, Array(block)
    end

    def child_added(&block)
      @when_added << block
    end

    def root
      root = self
      root = root.parent while root.parent
      root
    end
    
    # Call this method inside a child_added block to 
    # return a value as the result for this chain.
    def return(result = nil)
      throw :chain_return, (result || yield)
    end

    def <<(callable)
      catch :chain_return do
        chain = MessageChain.new(self, callable)
        messages << chain
        @when_added.each { |cb| cb.call(chain) }
        chain
      end
    end

    def method_missing(name, *args, &block)
      self << Message.new(name, args, block)
    end
    
    def call(object, injected = false)
      messages.inject(object) do |res, msg|
        res = object unless injected
        begin
          res = msg.call(res)
        rescue => e
          e.set_backtrace MessageChain.backtrace(msg, e)
          raise e
        end
        res = block_given? ? yield(res) : res
      end
    end

    def to_proc
      method(:call).to_proc
    end

    def empty?
      messages.empty?
    end

    def inspect
      "#<#{MessageChain} messages["+
        @messages.map(&:inspect).join(', ')+
        "] when_added(#{@when_added.inspect}"+
        ')>'
    end

    def to_s
      inspect
    end
    
    class << self

      def backtrace(msg, exception)
        bt = msg.backtrace if msg.respond_to?(:backtrace)
        bt = [Array(bt) + exception.backtrace].flatten
        bt.reject { |trace|  trace =~ /#{__FILE__}:|^:0$/ }
      end

      def collect(object, ivar, block = nil, *messages, &creator)
        creator ||= lambda { MessageChain.new }
        case ivar.to_s
        when /^@/
          getter = lambda { object.instance_variable_get(ivar) }
          setter = lambda { |v| object.instance_variable_set(ivar, v) }
        when /=$/
          getter = lambda { object[ivar] }
          setter = lambda { |v| object[ivar] = v }
        else
          getter = object.method(ivar)
          setter = object.method("#{ivar}=")
        end
        unless chain = getter.call
          chain = creator.call(object, ivar)
          setter.call(chain)
        end
        (messages << block).compact.inject(chain){ |a,b| a << b }
      end
      
      # Return a module with methods defined for each name, those
      # methods are used to collect messages on a message chain.
      #
      def collector(*names, &creator)
        Module.new do |mod|
          names.each do |name|
            Message.define(mod, name.to_s.gsub(/(^@|=$)/, '')) do |obj, msg|
              MessageChain.collect(mod, name, msg.block, *msg.args, &creator)
            end
          end
        end
      end
      
    end

  end # MessageChain
  
  # This class helps to create advices before/after/around already existing methods.
  class Advice
    
    class << self #:nodoc
      
      def before(*args, &block)
        define(Before, *args, &block)
      end
      
      def after(*args, &block)
        define(After, *args, &block)
      end
      
      def around(*args, &block)
        define(Around, *args, &block)
      end

      def before!(obj, *args, &block)
        define(Before, class << obj; self; end, *args, &block)
      end
      
      def after!(obj, *args, &block)
        define(After, class << obj; self; end, *args, &block)
      end
      
      def around!(obj, *args, &block)
        define(Around, class << obj; self; end, *args, &block)
      end

    private
      def define(type, *args, &block)
        new(*args, &block).tap { |adv| adv.extend(type); adv.install! if adv.enabled? }
      end

    end

    module Before #:nodoc:
      def advice_impl(obj, msg)
        catch(:advice_result) do 
          run_impl(obj, msg) if enabled?
          continue(obj, *msg.args, &msg.block)
        end
      end
    end

    module After #:nodoc:
      def advice_impl(obj, msg)
        catch(:advice_result) do
          continue(obj, *msg.args, &msg.block)
          enabled? ? run_impl(obj, msg) : result
        end
      end
    end

    module Around #:nodoc:
      def advice_impl(obj, msg)
        catch(:advice_result) { enabled? ? run_impl(obj, msg) : continue(obj, *msg.args, &msg.block) }
      end
    end

    attr_reader :name, :on_module
    attr_accessor :result
    
    # Create a new advice.
    def initialize(on_module, name, backup = nil, enabled = true, &impl)
      on_module.send :alias_method, backup, name if backup
      @adviced = on_module.instance_method(name)
      @on_module = on_module
      @name = name
      @impl = impl
      @enabled = !!enabled
    end

    def installed?
      @installed
    end

    # replace the adviced method with this advice implementation.
    def install!
      return if installed?
      Message.define(on_module, name, &method(:advice_impl))
      @installed = enable!
    end

    # remove this advice, restoring the previous adviced method
    def remove!
      return unless installed?
      adviced = @adviced
      name = @name
      @on_module.module_eval do 
        remove_method name
        define_method name, adviced
      end
      @installed = disable!
    end
    
    def return(value = result)
      throw :advice_result, value
    end
    
    # Run the implementation block, yielding the advice, object and message
    def run_impl(object, message)
      @result = @impl.call(*[self, object, message])
    end

    # Run the adviced method on object with the given args and block
    def continue(object, *args, &block)
      @result = @adviced.bind(object).call(*args, &block)
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

    def enabled?
      @enabled
    end

    def enable!
      @enabled = true
    end

    def disable!
      @enabled = false
    end

  end # Advice

end
