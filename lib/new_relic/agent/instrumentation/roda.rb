# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'new_relic/agent/parameter_filtering'

module NewRelic
  module Agent
    module Instrumentation
      module RodaInstrumentation
        extend self

        API_ENDPOINT   = 'api.endpoint'.freeze
        FORMAT_REGEX   = /\(\/?\.:format\)/.freeze
        VERSION_REGEX  = /:version(\/|$)/.freeze
        EMPTY_STRING   = ''.freeze
        MIN_VERSION    = VersionNumber.new("2.0.0")

        def handle_transaction(endpoint, class_name)
          return unless endpoint && route = endpoint.route
          name_transaction(route, class_name)
          capture_params(endpoint)
        end

        def name_transaction(route, class_name)
          txn_name = name_for_transaction(route, class_name)
          node_name = "Middleware/Roda/#{class_name}/call"
          Transaction.set_default_transaction_name(txn_name, :roda, node_name)
        end

        def name_for_transaction(route, class_name)
          action_name = route.route_path.sub(FORMAT_REGEX, EMPTY_STRING)
          method_name = route.route_method

          if route.route_version
            action_name = action_name.sub(VERSION_REGEX, EMPTY_STRING)
            "#{class_name}-#{route.route_version}#{action_name} (#{method_name})"
          else
            "#{class_name}#{action_name} (#{method_name})"
          end
        end

        def capture_params(endpoint)
          txn = Transaction.tl_current
          env = endpoint.request.env
          params = ParameterFiltering::apply_filters(env, endpoint.params)
          params.delete("route_info")
          txn.filtered_params = params
          txn.merge_request_parameters(params)
        end
      end
    end
  end
end

DependencyDetection.defer do
  named :roda_instrumentation

  depends_on do
    ::NewRelic::Agent.config[:disable_roda] == false
  end

  depends_on do
    defined?(::Roda::RodaVersion) &&
      ::NewRelic::VersionNumber.new(::Roda::RodaVersion) >= ::NewRelic::Agent::Instrumentation::RodaInstrumentation::MIN_VERSION
  end

  executes do
    NewRelic::Agent.logger.info 'Installing New Relic supported Roda instrumentation'
    instrument_call
  end

  def instrument_call
    ::Roda.class_eval do
      def call_with_new_relic(env)
        begin
          response = call_without_new_relic(env)
        ensure
          begin
            endpoint = env[::NewRelic::Agent::Instrumentation::RodaInstrumentation::API_ENDPOINT]
            ::NewRelic::Agent::Instrumentation::RodaInstrumentation.handle_transaction(endpoint, self.class.name)
          rescue => e
            ::NewRelic::Agent.logger.warn("Error in Roda instrumentation", e)
          end
        end

        response
      end

      alias_method :call_without_new_relic, :call
      alias_method :call, :call_with_new_relic
    end
  end

end
