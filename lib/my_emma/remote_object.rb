require 'httparty'
require 'rubygems'
require 'crack'
require 'active_model'

module MyEmma


  class RemoteObject
    include ActiveModel

    include HTTParty

    parser(
      ::Proc.new do |body, format|
        ::Crack::JSON.parse(body)
      end
    )

    # returns true if a key is expressible in ruby from external system
    def legal(key)
      return !(key.include?('-')|| !key.include?(' '))
    end

    def initialize(attr)
      attr.each do |key,val|
        if legal(key)
          check_key = key.to_sym

          if self.class.api_attributes.include?(check_key)
            unless self.methods.include?(check_key) then
              singleton_class.class_eval do; attr_reader "#{key}"; end
              if self.class.api_attributes.include?(check_key) then
                singleton_class.class_eval do; attr_writer "#{key}"; end
              end
            end
            self.instance_variable_set "@#{key}", val
          end
        end
      end

    end


    def self.set_http_values
      if base_uri.nil?
        base_uri MyEmma.base_uri
        basic_auth MyEmma.username, MyEmma.password
      end
    end

    def id
      nil
    end


    protected

    def persisted?
      return !self.id.nil?
    end

    def self.operation_ok?(response)
      [200,404].include?(response.code)
    end


  end
end
