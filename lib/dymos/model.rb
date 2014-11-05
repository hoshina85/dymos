require 'aws-sdk-core'
require 'active_model'

module Dymos
  class Model
    include ActiveModel::Model
    include ActiveModel::Dirty
    include ActiveModel::Callbacks
    include Dymos::Persistence
    extend Dymos::Command
    attr_accessor :metadata

    define_model_callbacks :save

    def initialize(params={})
      @attributes={}
      send :attributes=, params, true
      super
    end

    def self.field(attr, type, default: nil, desc: nil)
      fail StandardError('attribute name is invalid') if attr =~ /[\!\?]$/
      fail StandardError('require "default" option') if (type == :bool && default.nil?)

      @fields ||= {}
      @fields[attr]={
        type: type,
        default: default
      }
      define_attribute_methods attr

      define_model_callbacks attr
      define_method(attr) { |raw=false|
        run_callbacks attr do
        val = read_attribute(attr) || default
        return val if raw || !val.present?
        case type
          when :bool
            to_b(val)
          when :time
            Time.parse val
          when :integer
            val.to_i
          else
            val
        end
        end

      }
      define_method("#{attr}_type") { type }
      define_method("#{attr}_desc") { desc }
      define_method("#{attr}?") do
        val = self.send attr
        if type == :bool
          val
        else
          !val.nil?
        end
      end

      define_model_callbacks :"set_#{attr}"
      define_method("#{attr}=") do |value, initialize=false|
        run_callbacks :"set_#{attr}" do
        value = value.iso8601 if self.class.fields.include?(attr) && value.is_a?(Time)
        write_attribute(attr, value, initialize)
        end
      end
    end

    def self.fields
      @fields
    end


    def self.table(name)
      define_singleton_method('table_name') { name }
      define_method('table_name') { name }
    end

    def attributes=(attributes = {}, initialize = false)
      if attributes
        attributes.each do |attr, value|
          send("#{attr}=", value, initialize) if respond_to? "#{attr}="
        end
      end
    end

    def attributes(raw=false)
      attrs = {}
      @attributes.keys.each do |name|
        attrs[name] = send "#{name}", raw if respond_to? "#{name}"
      end
      attrs
    end

    def self.all
      self.scan.execute
    end

    def self.find(key1, key2=nil)
      indexes = key_scheme
      keys={}
      keys[indexes.first[:attribute_name].to_sym] = key1
      keys[indexes.last[:attribute_name].to_sym] = key2 if indexes.size > 1
      self.get.key(keys).execute
    end

    def self.key_scheme
      @key_scheme ||= new.describe_table[:table][:key_schema]
    end

    def reload!
      reset_changes
    end

    def describe_table
      self.class.send(:describe).execute
    end

    def indexes
      scheme = self.class.key_scheme.map do |scheme|
        [scheme[:attribute_name], send(scheme[:attribute_name])]
      end
      scheme.to_h
    end

    def dynamo
      @client ||= Aws::DynamoDB::Client.new
    end

    # @return [String]
    def self.class_name
      self.name
    end

    # @return [String]
    def class_name
      self.class.name
    end

    private
    def read_attribute(name)
      @attributes[name.to_sym]
    end

    def write_attribute(name, value, initialize=false)
      self.send "#{name}_will_change!" unless (initialize or value == @attributes[name.to_sym])
      @attributes[name.to_sym] = value
    end

    def to_b(val)
      compare_value = val.class == String ? val.downcase : val
      case compare_value
        when "yes", "true", "ok", true, "1", 1, :true, :ok, :yes
          true
        else
          false
      end
    end

  end
end
