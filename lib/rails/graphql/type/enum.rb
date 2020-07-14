# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Type # :nodoc:
      # = GraphQL EnumType
      #
      # Enum types, like scalar types, also represent leaf values in a GraphQL
      # type system. However Enum types describe the set of possible values.
      # See http://spec.graphql.org/June2018/#EnumTypeDefinition
      class Enum < Type
        extend ActiveSupport::Autoload
        extend Helpers::LeafFromAr

        setup! leaf: true, input: true, output: true
        set_ar_type! :enum

        eager_autoload do
          autoload :DirectiveLocationEnum
          autoload :TypeKindEnum
        end

        # Define the methods for accessing the values attribute
        inherited_collection :values

        # Define the methods for accessing the description of each enum value
        inherited_collection :value_description, default: {}

        # Define the methods for accessing the directives of each enum value
        inherited_collection :value_directives, default: {}

        class << self
          # Check if a given value is a valid non-deserialized input
          def valid_input?(value)
            value.is_a?(String) && all_values.include?(value)
          end

          # Check if a given value is a valid non-serialized output
          def valid_output?(value)
            value.respond_to?(:to_s) && all_values.include?(value.to_s)
          end

          # Transforms the given value to its representation in a JSON string
          def to_json(value)
            to_hash(value)&.inspect
          end

          # Transforms the given value to its representation in a Hash object
          def to_hash(value)
            value.to_s.underscore.upcase
          end

          # Turn a user input of this given type into an ruby object
          def deserialize(value)
            value
          end

          # Use this method to add values to the enum type
          #
          # ==== Options
          #
          # * <tt>:desc</tt> - The description of the enum value (defaults to nil).
          # * <tt>:directives</tt> - The list of directives associated with the value
          #   (defaults to nil).
          # * <tt>:deprecated</tt> - A shortcut that auto-attach a @deprecated
          #   directive to the value. A +true+ value simple attaches the directive,
          #   but provide a string so it can be used as the reason of the deprecation.
          #   See {DeprecatedDirective}[rdoc-ref:Rails::GraphQL::Directive::DeprecatedDirective]
          #   (defaults to false).
          def add(value, desc: nil, directives: nil, deprecated: false)
            value = to_hash(value)
            raise ArgumentError, <<~MSG.squish if all_values.include?(value)
              The "#{value}" is already defined for #{gql_name} enum.
            MSG

            directives = Array.wrap(directives)
            directives << deprecated_klass.new(
              reason: (deprecated.is_a?(String) ? deprecated : nil)
            ) if deprecated.present?

            directives = GraphQL.directives_to_set(directives,
              location: :enum_value,
              source:  self,
            )

            self.values << value
            self.value_description[value] = desc unless desc.nil?
            self.value_directives[value] = directives
          end

          # Build a hash with deprecated values and their respective reason for
          # logging and introspection purposes
          def all_deprecated_values
            @all_deprecated_values ||= begin
              all_value_directives.inject({}) do |list, (value, dirs)|
                next unless obj = dirs.find { |dir| dir.is_a?(deprecated_klass) }
                list.merge(value => obj.args.reason)
              end
            end.freeze
          end

          def inspect # :nodoc:
            <<~INFO.squish + '>'
              #<GraphQL::Enum #{gql_name}
              (#{all_values.size})
              {#{all_values.to_a.join(' | ')}}
            INFO
          end

          private

            def deprecated_klass
              Directive::DeprecatedDirective
            end
        end
      end
    end
  end
end
