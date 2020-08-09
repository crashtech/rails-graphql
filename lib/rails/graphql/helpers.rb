# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Helpers # :nodoc:
      extend ActiveSupport::Autoload

      autoload :AttributeDelegator
      autoload :InheritedCollection
      autoload :LeafFromAr
      autoload :Registerable

      autoload :WithArguments
      autoload :WithAssignment
      autoload :WithCallbacks
      autoload :WithDirectives
      autoload :WithEvents
      autoload :WithFields
      autoload :WithNamespace
      autoload :WithSchemaFields
      autoload :WithValidator

      # Easy way to duplicate objects and set a new owner
      def self.dup_all_with_owner(enumerator, owner)
        enumerator.map { |item| dup_with_owner(item, owner) }
      end

      # Easy way to duplicate a object and set a new owner
      def self.dup_with_owner(item, owner)
        item.dup.tap { |x| x.instance_variable_set(:@owner, owner) }
      end
    end
  end
end
