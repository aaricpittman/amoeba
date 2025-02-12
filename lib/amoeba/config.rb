# frozen_string_literal: true

module Amoeba
  class Config
    DEFAULTS = {
      enabled: false,
      inherit: false,
      parenting: false,
      raised: false,
      dup_method: :dup,
      remap_method: nil,
      includes: {},
      excludes: {},
      clones: [],
      after_associations: [],
      before_associations: [],
      null_fields: [],
      coercions: {},
      prefixes: {},
      suffixes: {},
      regexes: {},
      known_macros: %i[has_one has_many has_and_belongs_to_many]
    }.freeze

    DEFAULTS.each do |key, value|
      value.freeze if value.is_a?(Array) || value.is_a?(Hash)
      class_eval <<-EOS, __FILE__, __LINE__ + 1
        def #{key}          # def enabled
          @config[:#{key}]  #   @config[:enabled]
        end                 # end
      EOS
    end

    def initialize(klass)
      @klass  = klass
      @config = self.class::DEFAULTS.deep_dup
    end

    alias upbringing raised

    def enable
      @config[:enabled] = true
    end

    def disable
      @config[:enabled] = false
    end

    def raised(style = :submissive)
      @config[:raised] = style
    end

    def propagate(style = :submissive)
      @config[:parenting] ||= style
      @config[:inherit] = true
    end

    def push_value_to_array(value, key)
      res = @config[key]
      if value.is_a?(::Array)
        res = value
      elsif value
        res << value
      end
      @config[key] = res.uniq
    end

    def push_array_value_to_hash(value, config_key)
      @config[config_key] = {}

      value.each do |definition|
        definition.each do |key, val|
          fill_hash_value_for(config_key, key, val)
        end
      end
    end

    def push_value_to_hash(value, config_key)
      if value.is_a?(Array)
        push_array_value_to_hash(value, config_key)
      else
        value.each do |key, val|
          fill_hash_value_for(config_key, key, val)
        end
      end
      @config[config_key]
    end

    def fill_hash_value_for(config_key, key, val)
      @config[config_key][key] = val if val || (!val.nil? && config_key == :coercions)
    end

    def include_association(value = nil, options = {})
      enable
      @config[:excludes] = {}
      value = value.is_a?(Array) ? value.map! { |v| [v, options] }.to_h : { value => options }
      push_value_to_hash(value, :includes)
    end

    def include_associations(*values)
      values.flatten.each { |v| include_association(v) }
    end

    def exclude_association(value = nil, options = {})
      enable
      @config[:includes] = {}
      value = value.is_a?(Array) ? value.map! { |v| [v, options] }.to_h : { value => options }
      push_value_to_hash(value, :excludes)
    end

    def exclude_associations(*values)
      values.flatten.each { |v| exclude_association(v) }
    end

    def clone(value = nil)
      enable
      push_value_to_array(value, :clones)
    end

    def recognize(value = nil)
      enable
      push_value_to_array(value, :known_macros)
    end

    {
      before_associations: 'before_associations',
      after_associations: 'after_associations'
    }.each do |method, key|
      class_eval <<-EOS, __FILE__, __LINE__ + 1
        def #{method}(*hooks, &block)
          value = 
            if block
              block
            elsif hooks.length < 2
              hooks.first
            else
              hooks
            end

          push_value_to_array(value, :#{key})
        end
      EOS
    end
    alias before_assoc before_associations
    alias override before_associations
    alias after_assoc after_associations
    alias customize after_associations

    def nullify(value = nil)
      push_value_to_array(value, :null_fields)
    end

    {
      set: 'coercions',
      prepend: 'prefixes',
      append: 'suffixes',
      regex:'regexes'
    }.each do |method, key|
      class_eval <<-EOS, __FILE__, __LINE__ + 1
        def #{method}(value = nil)
          push_value_to_hash(value, :#{key})
        end
      EOS
    end

    def through(value)
      @config[:dup_method] = value.to_sym
    end

    def remapper(value)
      @config[:remap_method] = value.to_sym
    end
  end
end
