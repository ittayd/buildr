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

  class ::Object
    alias_method :require_without_buildr_autoload, :require
    
    def require_with_buildr_autoload(feature)
      Buildr::Autoload.requiring(feature) do
        if ctx = Buildr::Context.current
          ctx.application.switch_to_namespace([]) do
            require_without_buildr_autoload(feature)
          end
        else
          require_without_buildr_autoload(feature)
        end
      end
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

    # Lookup the task name
    def lookup_in_scope(name, scope)
      n = scope.size
      while n >= 0
        tn = (scope[0,n] + [name]).join(':')
        task = @tasks[tn] || lazy_task(tn)
        return task if task
        n -= 1
      end
      nil
    end

    def lazy_task(task)
      features = []
      LazyRake.lazy_tasks.delete_if { |f,a| a.any? { |r| r === task } && features << f }
      unless features.empty?
        features.each { |feature| feature.respond_to?(:call) ? feature.call(task) : Object.require(feature) }
      end
      @tasks[task]
    end

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
      cand = []
      cand << "Object::#{name}::#{miss}" unless self == Object
      names.size.times { |i| cand <<  (names[0..(0 - (i+1))] + [miss]).join('::') }
      LazyConst.lazy_consts.delete_if do |r,f|
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
    
    class << self
      def autoload(feature, name, attrs = {})
        compiler = Class.new(Compiler::Base)
        Compiler.compilers << compiler
        meta = class << compiler; self; end
        meths = compiler.singleton_methods - instance_methods(false)
        Message.define(meta, meths) do |obj, msg|
          msg.call LazyCompiler[name]
        end
        compiler.extend self
        attrs.update :feature => feature, :name => name
        attrs.each { |a, v| compiler.instance_variable_set("@#{a}", v) }
      end

      def [](compiler_name)
        cmp = Compiler.select(compiler_name)
        cmp = cmp.real if LazyCompiler === cmp
        cmp
      end
    end

    def real
      Compiler.compilers.delete(self)
      require @feature
      Compiler.select(to_sym)
    end

    def new(*args, &block)
      LazyCompiler[to_sym].new(*args, &block)
    end

    def name
      @name.to_s
    end

    def to_sym
      @name
    end

  end # LazyCompiler

  def Buildr.Autoload(&block)
    Autoload.module_eval(&block)
  end

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

    def compiler(feature, *args, &block)
      if defined?(Compiler)
        before_require! feature
      else
        after_require 'buildr/core/compile' do
          LazyCompiler.autoload(feature, *args, &block)
        end
      end
    end

    def tester(*args, &block)
      # TODO: define autoloaded test frameworks
    end

    def on_requires
      @on_requires ||= Hash.new { |h,k| h[k] = [[], []] }
    end

    def requiring(feature)
      Message.remove_before_autoload(feature)
      before, after = on_requires[feature]
      before.map(&:call)
      res = yield
      after.map(&:call)
      res
    end

    def before_require(feature, &before)
      on_requires[feature].first << before if before
    end

    def before_require!(feature, &before)
      before_require(feature, &before) if before
      Application.boot { require feature }
    end

    def after_require(feature, &after)
      on_requires[feature].last << after if after
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

