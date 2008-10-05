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


require 'buildr/core/ruby_ext'
require 'buildr/core/message'
require 'buildr/core/rake_ext'
require 'buildr/core/application'
require 'buildr/core/application_cli'

module Buildr #:nodoc:

  class << self

    def before_requires
      @before_requires ||= Hash.new
    end

    def before_require(feature, &before)
      if prev = before_requires[feature] 
        before_requires[feature] = lambda { prev.call; before.call }
      else
        before_requires[feature] = before
      end
    end
    
    def before_require!(feature, &before)
      before_require(feature, &before)
      Application.boot { require feature }
    end
    
  end # << Buildr

  class ::Object
    alias_method :require_without_buildr_autoload, :require
    
    def require_with_buildr_autoload(feature)
      Buildr::Message.remove_before_autoload(feature)
      if before = Buildr.before_requires.delete(feature)
        before.call
      end
      require_without_buildr_autoload(feature)
    end

    alias_method :require, :require_with_buildr_autoload
  end

  class Message
    class << self

      def autoloads
        @autoloads ||= Hash.new { |h,k| h[k] = [] }
      end
      
      def remove_before_autoload(feature)
        if msgs = autoloads.delete(feature)
          msgs.each { |on_module, msg_name| on_module.send :remove_method, msg_name }
        end
      end
      
      # Autoload messages on module from feature.
      def autoload(feature, on_module, *names, &block)
        names.each { |n| autoloads[feature] |= [[on_module, n]] }
        define(on_module, names) do |obj, msg|
          feature.respond_to?(:call) ? feature.call(obj, msg) : Object.require(feature)
          block ? block.call(obj, msg) : msg.call(obj)
        end
      end
      
    end
  end # Message

  module ::Rake::TaskManager
    alias_method :at_without_buildr_autoload, :[]
    
    def at_with_buildr_autoload(task, *args, &block)
      features = []
      LazyRake.lazy_tasks.delete_if { |f,a| a.any? { |r| r === task } && features << f }
      unless features.empty?
        features.each { |feature| feature.respond_to?(:call) ? feature.call(task) : Object.require(feature) }
      end
      at_without_buildr_autoload(task, *args, &block)
    end
    
    alias_method :[], :at_with_buildr_autoload
  end

  module LazyRake
    class << self

      def lazy_tasks
        @lazy_tasks ||= Hash.new { |h, k| h[k] = [] }
      end

      # require feature to load task
      def task(feature, *tasks)
        raise 'No task patterns given' if tasks.empty?
        lazy_tasks[feature] |= tasks
      end
    end
  end # LazyRake

  class ::Module
    alias_method :const_missing_without_buildr_autoload, :const_missing
    
    def const_missing_with_buildr_autoload(miss)
      names = name.split('::')
      const = nil
      features = []
      LazyConst.lazy_consts.delete_if do |r,f|
        cand = []
        names.size.times { |i| cand <<  (names[0..(0 - (i+1))] + [miss]).join('::') }
        cand.any? { |c| r === c and const = c and features << f }
      end
      features = features.flatten.compact
      if features.empty?
        const_missing_without_buildr_autoload(miss)
      else
        LazyConst.lazy_consts.delete_if { |r, fs| fs.delete_if { |f| features.include?(f) }; fs.empty? }
        features.each { |feature| feature.respond_to?(:call) ? feature.call(const) : Object.require(feature) }
        eval(const, TOPLEVEL_BINDING, __FILE__, __LINE__)
      end
    end

    alias_method :const_missing, :const_missing_with_buildr_autoload
  end

  module LazyConst
    class << self

      def lazy_consts
        @lazy_consts ||= Hash.new { |h, k| h[k] = [] }
      end
      
      def autoload(feature_map)
        normalize = lambda do |name|
          if String === name || Symbol === name
            name = name.to_s
            name = 'Buildr::' + name unless name =~ /^::*/
            name.gsub(/^::+/, 'Object::')
          else
            name
          end
        end
        feature_map.each_pair { |k, v| Array(k).each { |c| lazy_consts[normalize[c]] |= Array(v) } }
      end
      
    end
  end # LazyConst

  module LazyCompiler
    
  end # LazyCompiler

  module Autoload
    extend self

    def task(*args, &block)
      LazyRake.task(*args, &block)
    end
    
    def method(*args, &block)
      Message.autoload(*args, &block)
    end

    def const(*args, &block)
      LazyConst.autoload(*args, &block)
    end

    def compiler(*args, &block)
      # TODO: define autoloaded compilers
    end

    def tester(*args, &block)
      # TODO: define autoloaded test frameworks
    end

  end

  Application.boot do
    # The projects already present when auto loading extensions
    early_projects = []
    
    # modules including Extension have their before_define
    # actions added here. So we collect the early projects.
    Project.before_define do |project|
      # when a new extension is autoloaded
      early_projects << project if Context.current
    end
    
    # This hook is called when a new Extension callback 
    # is registered on Project.before_define chain.
    # We init the early projects with those extensions.
    Project.before_define.child_added do |child|
      if Context.current
        projs = early_projects.dup
        projs.each do |proj|
          child.call(proj)
          Project.before_define.messages.delete(proj)
        end
      end
    end
  end
  
end # Buildr

