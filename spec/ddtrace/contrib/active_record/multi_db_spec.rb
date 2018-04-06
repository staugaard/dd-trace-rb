require 'spec_helper'
require 'ddtrace'

require 'active_record'
require 'mysql2'
require 'sqlite3'

RSpec.describe 'ActiveRecord multi-database implementation' do
  let(:tracer) { ::Datadog::Tracer.new(writer: FauxWriter.new) }
  let(:configuration_options) { { tracer: tracer, service_name: default_db_service_name } }
  let(:default_db_service_name) { 'default-db' }

  let(:application_record) do
    stub_const('ApplicationRecord', Class.new(ActiveRecord::Base) do
      self.abstract_class = true
    end)
  end

  let!(:gadget_class) do
    stub_const('Gadget', Class.new(application_record)).tap do |klass|
      # Connect to the default database
      ActiveRecord::Base.establish_connection('mysql2://root:root@127.0.0.1:53306/mysql')

      begin
        klass.count
      rescue ActiveRecord::StatementInvalid
        ActiveRecord::Schema.define(version: 20180101000000) do
          create_table 'gadgets', force: :cascade do |t|
            t.string   'title'
            t.datetime 'created_at', null: false
            t.datetime 'updated_at', null: false
          end
        end

        # Prevent extraneous spans from showing up
        klass.count
      else
        # Do nothing
      end
    end
  end

  let!(:widget_class) do
    stub_const('Widget', Class.new(application_record)).tap do |klass|
      # Connect the Widget database
      klass.establish_connection(adapter: 'sqlite3', database: ':memory:')

      begin
        klass.count
      rescue ActiveRecord::StatementInvalid
        klass.connection.create_table 'widgets', force: :cascade do |t|
          t.string   'title'
          t.datetime 'created_at', null: false
          t.datetime 'updated_at', null: false
        end

        # Prevent extraneous spans from showing up
        klass.count
      else
        # Do nothing
      end
    end
  end

  subject(:spans) do
    gadget_class.count
    widget_class.count
    tracer.writer.spans
  end

  let(:gadget_span) { spans[0] }
  let(:widget_span) { spans[1] }

  before(:each) do
    Datadog.configuration[:active_record].reset_options!

    Datadog.configure do |c|
      c.use :active_record, configuration_options
    end
  end

  after(:each) do
    Datadog.configuration[:active_record].reset_options!
  end

  context 'when :databases is configured with' do
    let(:configuration_options) { super().merge(databases: databases) }
    let(:widget_db_configuration_options) { { service_name: widget_db_service_name } }
    let(:widget_db_service_name) { 'widget-db' }

    # context 'a Symbol that matches a configuration' do
    # end

    # context 'a String that\'s a URL' do
    # end

    context 'a Hash that describes a connection' do
      let(:databases) { { { adapter: 'sqlite3', database: ':memory:' } => widget_db_configuration_options } }

      it do
        # Gadget belongs to the default database
        expect(gadget_span.service).to eq(default_db_service_name)
        # Widget belongs to its own database
        expect(widget_span.service).to eq(widget_db_service_name)
      end
    end
  end
end
