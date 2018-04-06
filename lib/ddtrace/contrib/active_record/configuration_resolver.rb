module Datadog
  module Contrib
    module ActiveRecord
      class ConfigurationResolver
        def initialize(configurations)
          # TODO: Based on ActiveRecord version, choose resolver.
          @resolver = ::ActiveRecord::ConnectionAdapters::ConnectionSpecification::Resolver.new(configurations)
        end

        def resolve(spec)
          normalize(@resolver.resolve(spec).symbolize_keys)
        end

        def normalize(hash)
          {
            adapter:  hash[:adapter],
            host:     hash[:host],
            port:     hash[:port],
            database: hash[:database],
            username: hash[:username]
          }
        end
      end
    end
  end
end
