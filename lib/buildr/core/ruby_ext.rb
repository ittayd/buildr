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

if RUBY_VERSION < '1.9.0'
  module Kernel #:nodoc:
    # Borrowed from Ruby 1.9.
    def tap
      yield self if block_given?
      self
    end unless method_defined?('tap')
  end


  class Symbol #:nodoc:
    # Borrowed from Ruby 1.9.
    def to_proc
      Proc.new{|*args| args.shift.__send__(self, *args)}
    end unless method_defined?('to_proc')
  end

  # Also borrowed from Ruby 1.9.
  class BasicObject #:nodoc:
    (instance_methods - ['__send__', '__id__', '==', 'send', 'send!', 'respond_to?', 'equal?', 'object_id']).
      each do |method|
      undef_method method
    end

    def self.ancestors
      [Kernel]
    end
  end

  unless Kernel.respond_to?(:instance_exec)
    # Also borrowed from Ruby 1.9.
    class Object # :nodoc:
      def instance_exec(*arguments, &block)
        block.bind(self)[*arguments]
      end
    end
    
    # Needed for instance_exec
    class Proc #:nodoc:
      def bind(object)
        block, time = self, Time.now
        (class << object; self end).class_eval do
          method_name = "__bind_#{time.to_i}_#{time.usec}"
          define_method(method_name, &block)
          method = instance_method(method_name)
          remove_method(method_name)
          method
        end.bind(object)
      end
    end
  end

end


class OpenObject < Hash

  def initialize(source=nil, &block)
    @hash = Hash.new(&block)
    @hash.update(source) if source
  end

  def [](key)
    @hash[key]
  end

  def []=(key, value)
    @hash[key] = value
  end

  def delete(key)
    @hash.delete(key)
  end

  def to_hash
    @hash.clone
  end

  def method_missing(symbol, *args)
    if symbol.to_s =~ /=$/
      self[symbol.to_s[0..-2].to_sym] = args.first
    else
      self[symbol]
    end
  end
end


class Hash

  class << self

    # :call-seq:
    #   Hash.from_java_properties(string)
    #
    # Returns a hash from a string in the Java properties file format. For example:
    #   str = 'foo=bar\nbaz=fab'
    #   Hash.from_properties(str)
    #   => { 'foo'=>'bar', 'baz'=>'fab' }.to_properties
    def from_java_properties(string)
      hash = {}
      input_stream = Java.java.io.StringBufferInputStream.new(string)
      java_properties = Java.java.util.Properties.new
      java_properties.load input_stream
      keys = java_properties.keySet.iterator
      while keys.hasNext
        # Calling key.next in JRuby returns a java.lang.String, behaving as a Ruby string and life is good.
        # MRI, unfortunately, treats next() like the interface says returning an object that's not a String,
        # and the Hash doesn't work the way we need it to.  Unfortunately, we can call toString on MRI's object,
        # but not on the JRuby one; calling to_s on the JRuby object returns what we need, but ... you guessed it.
        #  So this seems like the one hack to unite them both.
        key = Java.java.lang.String.valueOf(keys.next)
        hash[key] = java_properties.getProperty(key)
      end
      hash
    end

  end

  # :call-seq:
  #   only(keys*) => hash
  #
  # Returns a new hash with only the specified keys.
  #
  # For example:
  #   { :a=>1, :b=>2, :c=>3, :d=>4 }.only(:a, :c)
  #   => { :a=>1, :c=>3 }
  def only(*keys)
    keys.inject({}) { |hash, key| has_key?(key) ? hash.merge(key=>self[key]) : hash }
  end


  # :call-seq:
  #   except(keys*) => hash
  #
  # Returns a new hash without the specified keys.
  #
  # For example:
  #   { :a=>1, :b=>2, :c=>3, :d=>4 }.except(:a, :c)
  #   => { :b=>2, :d=>4 }
  def except(*keys)
    (self.keys - keys).inject({}) { |hash, key| hash.merge(key=>self[key]) }
  end

  # :call-seq:
  #   to_java_properties => string
  #
  # Convert hash to string format used for Java properties file. For example:
  #   { 'foo'=>'bar', 'baz'=>'fab' }.to_properties
  #   => foo=bar
  #      baz=fab
  def to_java_properties
    keys.sort.map { |key|
      value = self[key].gsub(/[\t\r\n\f\\]/) { |escape| "\\" + {"\t"=>"t", "\r"=>"r", "\n"=>"n", "\f"=>"f", "\\"=>"\\"}[escape] }
      "#{key}=#{value}"
    }.join("\n")
  end

end
