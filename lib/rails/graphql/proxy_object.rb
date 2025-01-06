# frozen_string_literal: true

module Rails
  module GraphQL
    # This class imitates the behavior of ActiveSupport::ProxyObject
    # Provides a minimal proxy object that delegates method calls to a target object
    class ProxyObject < BasicObject
      def initialize(target = nil)
        @__target = target
      end

      # Dynamically delegates method calls to the target object
      def method_missing(method_name, *args, **kwargs, &block)
        if target.respond_to?(method_name)
          target.public_send(method_name, *args, **kwargs, &block)
        else
          super
        end
      end

      # Check if the target object responds to a method
      def respond_to_missing?(method_name, include_private = false)
        target.respond_to?(method_name, include_private)
      end

      private

      # Returns the target object for delegation
      def target
        @__target
      end
    end
  end
end
