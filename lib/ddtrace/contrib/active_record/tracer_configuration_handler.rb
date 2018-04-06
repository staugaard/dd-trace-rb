require 'ddtrace/contrib/active_record/configuration_resolver'

module Datadog
  module Contrib
    module ActiveRecord
      class TracerConfigurationHandler
        def initialize(configurations = ::ActiveRecord::Base.configurations)
          @resolver = ConfigurationResolver.new(configurations)
        end

        def get(spec)
          connection_config = @resolver.resolve(spec)
          tracer_configs[connection_config] || {}
        end

        def set(spec, tracer_config)
          connection_config = @resolver.resolve(spec)
          tracer_configs[connection_config] = tracer_config unless connection_config.nil?
        end

        def tracer_configs
          @tracer_configs ||= {}
        end
      end
    end
  end
end
