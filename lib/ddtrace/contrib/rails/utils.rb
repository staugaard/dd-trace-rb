module Datadog
  module Contrib
    module Rails
      # common utilities for Rails
      module Utils
        # in Rails the template name includes the template full path
        # and it's better to avoid storing such information. This method
        # returns the relative path from `views/` or the template name
        # if a `views/` folder is not in the template full path. A wrong
        # usage ensures that this method will not crash the tracing system.
        def self.normalize_template_name(name)
          return if name.nil?

          base_path = Datadog.configuration[:rails][:template_base_path]
          sections_view = name.split(base_path)

          if sections_view.length == 1
            name.split('/')[-1]
          else
            sections_view[-1]
          end
        rescue
          return name.to_s
        end

        # TODO: Consider moving this out of Rails.
        # Return a canonical name for a type of database
        def self.normalize_vendor(vendor)
          case vendor
          when nil
            'defaultdb'
          when 'sqlite3'
            'sqlite'
          when 'postgresql'
            'postgres'
          else
            vendor
          end
        end

        def self.app_name
          if ::Rails::VERSION::MAJOR >= 4
            ::Rails.application.class.parent_name.underscore
          else
            ::Rails.application.class.to_s.underscore
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
            database_name: config[:database]
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
          return @default_connection_config unless @default_connection_config.nil?
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

        def self.exception_is_error?(exception)
          if defined?(::ActionDispatch::ExceptionWrapper)
            # Gets the equivalent status code for the exception (not all are 5XX)
            # You can add custom errors via `config.action_dispatch.rescue_responses`
            status = ::ActionDispatch::ExceptionWrapper.status_code_for_exception(exception.class.name)
            # Only 5XX exceptions are actually errors (e.g. don't flag 404s)
            status.to_s.starts_with?('5')
          else
            true
          end
        end
      end
    end
  end
end
