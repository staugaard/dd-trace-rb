require 'ddtrace/contrib/active_record/tracer_configuration_handler'

module Datadog
  module Contrib
    module ActiveRecord
      # Common utilities for Rails
      module Utils
        # Return a canonical name for a type of database
        def self.normalize_vendor(vendor)
          case vendor
          when nil
            'defaultdb'
          when 'postgresql'
            'postgres'
          when 'sqlite3'
            'sqlite'
          else
            vendor
          end
        end

        def self.adapter_name
          connection_config[:adapter_name]
        end

        def self.database_name
          connection_config[:database_name]
        end

        def self.adapter_host
          connection_config[:adapter_host]
        end

        def self.adapter_port
          connection_config[:adapter_port]
        end

        def self.connection_config(object_id = nil)
          config = object_id.nil? ? default_connection_config : connection_config_by_id(object_id)
          {
            adapter_name: normalize_vendor(config[:adapter]),
            adapter_host: config[:host],
            adapter_port: config[:port],
            database_name: config[:database],
            tracer_config: tracer_config(config)
          }
        end

        # Attempt to retrieve the connection from an object ID.
        def self.connection_by_id(object_id)
          return nil if object_id.nil?
          ObjectSpace._id2ref(object_id)
        rescue StandardError
          nil
        end

        # Attempt to retrieve the connection config from an object ID.
        # Typical of ActiveSupport::Notifications `sql.active_record`
        def self.connection_config_by_id(object_id)
          connection = connection_by_id(object_id)
          return {} if connection.nil?

          if connection.instance_variable_defined?(:@config)
            connection.instance_variable_get(:@config)
          else
            {}
          end
        end

        def self.default_connection_config
          return @default_connection_config if instance_variable_defined?(:@default_connection_config)
          current_connection_name = if ::ActiveRecord::Base.respond_to?(:connection_specification_name)
                                      ::ActiveRecord::Base.connection_specification_name
                                    else
                                      ::ActiveRecord::Base
                                    end

          connection_pool = ::ActiveRecord::Base.connection_handler.retrieve_connection_pool(current_connection_name)
          connection_pool.nil? ? {} : (@default_connection_config = connection_pool.spec.config)
        rescue StandardError
          {}
        end

        # TODO: Extract this to Patcher
        def self.tracer_config(spec)
          __tracer_config_handler.get(spec)
        end

        def self.add_tracer_config(config)
          __tracer_config_handler.tap do |handler|
            config.each do |spec, tracer_config|
              handler.set(spec, tracer_config)
            end
          end
        end

        def self.__tracer_config_handler
          @__tracer_config_handler ||= ::Datadog::Contrib::ActiveRecord::TracerConfigurationHandler.new
        end
      end
    end
  end
end
