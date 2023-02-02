# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Source Active Record
    #
    # This source allows the translation of active record objects into a new
    # source object, creating:
    # 1. 1 Object
    # 2. 1 Input
    # 3. 2 Query fields (singular and plural)
    # 4. 3 Mutation fields (create, update, destroy)
    class Source::ActiveRecordSource < Source::Base
      include Source::ScopedArguments

      require_relative 'active_record/builders'
      extend Builders

      validate_assignment('ActiveRecord::Base') do |value|
        +"The \"#{value.name}\" is not a valid Active Record model"
      end

      # Mark if the objects created from this source will build fields for
      # associations associated to the object
      class_attribute :with_associations, instance_accessor: false, default: true

      # The name of the class (or the class itself) to be used as superclass for
      # the generate GraphQL interface type of this source
      class_attribute :interface_class, instance_accessor: false

      %i[object interface input].each do |type|
        settings = { abstract: true, with_owner: true }
        send("#{type}_class=", create_type(type, **settings))
      end

      self.abstract = true
      self.hook_names = hook_names.to_a.insert(1, :enums).to_set.freeze

      delegate :primary_key, :singular, :plural, :model, :id_columns, to: :class

      skip_from(:input, :created_at, :updated_at)

      step(:start) { GraphQL.enable_ar_adapter(adapter_name) }
      step(:enums) { build_enum_types }

      step(:object) do
        build_attribute_fields(self)
        build_reflection_fields(self)
      end

      step(:input) do
        extra = GraphQL.enumerate(primary_key).entries.product([{ null: true }]).to_h
        build_attribute_fields(self, **extra)
        build_reflection_inputs(self)

        safe_field(model.inheritance_column, :string, null: false) if object.interface?
        safe_field(:_delete, :boolean, default: false)

        reference = model.new
        model.columns_hash.each_value do |column|
          change_field(column.name, default: reference[column.name]) \
            if column.default.present? && has_field?(column.name)
        end
      end

      step(:query) do
        build_object

        safe_field(plural, object, full: true) do
          before_resolve(:load_records)
        end

        safe_field(singular, object, null: false) do
          build_primary_key_arguments(self)
          before_resolve(:load_record)
        end
      end

      step(:mutation) do
        build_object
        build_input

        safe_field("create_#{singular}", object, null: false) do
          argument(singular, input, null: false)
          perform(:create_record)
        end

        safe_field("update_#{singular}", object, null: false) do
          build_primary_key_arguments(self)
          argument(singular, input, null: false)
          before_resolve(:load_record)
          perform(:update_record)
        end

        safe_field("delete_#{singular}", :boolean, null: false) do
          build_primary_key_arguments(self)
          before_resolve(:load_record)
          perform(:destroy_record)
        end
      end

      class << self
        delegate :primary_key, :model_name, to: :model
        delegate :singular, :plural, :param_key, to: :model_name
        delegate :adapter_name, to: 'model.connection'

        alias interface interface_class
        alias model assigned_class
        alias model= assigned_to=

        # Set the assignment to a model with a similar name as the source
        def assigned_to
          @assigned_to ||= name.delete_prefix('GraphQL::')[0..-7]
        end

        # Stores columns associated with enums so that the fields can have a
        # correctly assigned type
        def enums
          @enums ||= model.defined_enums.dup
        end

        # Just a little override to ensure that both model and table are ready
        def build!(*)
          super if model&.table_exists?
        end

        # Hook into the unregister to clean enums
        def unregister!
          super
          @enums = nil
        end

        protected

          # Check if a given +attr_name+ is associated with a presence validator
          # (that does not include +if+ nor +unless+), but ignores when there is
          # a default value
          def attr_required?(attr_name)
            return true if attr_name.eql?(primary_key)
            return false if model.columns_hash[attr_name]&.default.present?
            return false unless model._validators.key?(attr_name.to_sym)

            model._validators[attr_name.to_sym].any? do |validator|
              validator.is_a?(presence_validator) &&
                !(validator.options[:if] ||
                  validator.options[:unless])
            end
          rescue ::ActiveRecord::StatementInvalid
            false
          end

        private

          def presence_validator
            ::ActiveRecord::Validations::PresenceValidator
          end
      end

      # Prepare to load multiple records from the underlying table
      def load_records(scope = model.default_scoped)
        inject_scopes(scope, :relation)
      end

      # Prepare to load a single record from the underlying table
      def load_record(scope = model.default_scoped, find_by: nil)
        find_by ||= { primary_key => event.argument(primary_key) }
        inject_scopes(scope, :relation).find_by(find_by)
      end

      # Get the chain result and preload the records with thre resulting scope
      def preload_association(association, scope = nil)
        event.stop(preload(association, scope || event.last_result), layer: :object)
      end

      # Collect a scope for filters applied to a given association
      def build_association_scope(association)
        scope = model._reflect_on_association(association).klass.default_scoped

        # Apply proxied injected scopes
        proxied = event.field.try(:proxied_owner)
        scope = event.on_instance(proxied) do |instance|
          instance.inject_scopes(scope, :relation)
        end if proxied.present? && proxied <= Source::ActiveRecordSource

        # Apply self defined injected scopes
        inject_scopes(scope, :relation)
      end

      # Once the records are pre-loaded due to +preload_association+, use the
      # parent value and the preloader result to get the records
      def parent_owned_records(collection_result = false)
        data = event.data[:prepared]
        return collection_result ? [] : nil unless data

        result = data.records_by_owner[current_value] || []
        collection_result ? result : result.first
      end

      # The perform step for the +create+ based mutation
      def create_record
        input_argument.resource.tap(&:save!)
      end

      # The perform step for the +update+ based mutation
      def update_record
        current_value.tap { |record| record.update!(**input_argument.params) }
      end

      # The perform step for the +delete+ based mutation
      def destroy_record
        !!current_value.destroy!
      end

      protected

        # Basically get the argument associated to the input
        def input_argument
          event.argument(singular)
        end

        # Preload the records for a given +association+ using the current value.
        # It can be further specified with a given +scope+
        # TODO: On Rails 7 we can use the Preloader::Branch class
        def preload(association, scope = nil)
          reflection = model._reflect_on_association(association)
          records = current_value.is_a?(preloader_association) \
            ? current_value.preloaded_records \
            : Array.wrap(current_value.itself).compact

          klass = preload_class(reflection)
          args = [reflection.klass, records, reflection, scope]
          args << nil if klass.instance_method(:initialize).arity == 6 # Rails 7
          klass.new(*args, true).run
        end

        # Get the cached instance of active record preloader
        def preload_class(reflection)
          if reflection.options[:through]
            ::ActiveRecord::Associations::Preloader::ThroughAssociation
          else
            ::ActiveRecord::Associations::Preloader::Association
          end
        end

      private

        def preloader_association
          ActiveRecord::Associations::Preloader::Association
        end
    end
  end
end
