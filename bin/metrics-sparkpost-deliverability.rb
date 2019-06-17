#!/usr/bin/env ruby
#
#   metrics-sparkpost-deliverability
#
# DESCRIPTION:
#   Query SparkPost API for deliverability metrics as time series.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Ruby is shit.
#
# LICENSE:
#   Copyright 2018 Nicolas Boutet
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'net/http'
require 'json'
require 'date'

class SparkpostDeliverabilityMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :apikey,
         short: '-k APIKEY',
         long: '--apikey APIKEY',
         description: 'Your SparkPost API Key',
         required: true

  option :from,
         short: '-f FROM',
         long: '--from FROM',
         description: 'Datetime in format of YYYY-MM-DDTHH:MM',
         required: true

  option :precision,
         short: '-p PRECISION',
         long: '--precision PRECISION',
         description: 'Precision among 1min, 5min, 15min, hour, 12hr, day, week, month',
         default: '1min'

  option :metrics,
         short: '-m METRICS',
         long: '--metrics METRICS',
         description: 'Metrics to fetch, possible values: count_targeted,count_injected,count_sent,count_accepted,count_delivered,count_delivered_first,count_delivered_subsequent,count_rendered,count_initial_rendered,count_unique_rendered,count_unique_initial_rendered,count_unique_confirmed_opened,count_clicked,count_unique_clicked,count_bounce,count_hard_bounce,count_soft_bounce,count_block_bounce,count_admin_bounce,count_undetermined_bounce,count_rejected,count_policy_rejection,count_generation_failed,count_generation_rejection,count_inband_bounce,count_outofband_bounce,count_delayed,count_delayed_first,total_msg_volume,count_spam_complaint,total_delivery_time_first,total_delivery_time_subsequent,count_unsubscribe',
         default: 'count_targeted,count_injected,count_sent,count_accepted,count_delivered,count_delivered_first,count_delivered_subsequent,count_rendered,count_initial_rendered,count_unique_rendered,count_unique_initial_rendered,count_unique_confirmed_opened,count_clicked,count_unique_clicked,count_bounce,count_hard_bounce,count_soft_bounce,count_block_bounce,count_admin_bounce,count_undetermined_bounce,count_rejected,count_policy_rejection,count_generation_failed,count_generation_rejection,count_inband_bounce,count_outofband_bounce,count_delayed,count_delayed_first,total_msg_volume,count_spam_complaint,total_delivery_time_first,total_delivery_time_subsequent,count_unsubscribe'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         required: true,
         default: 'sparkpost.deliverability'

  def run

    uri = URI('https://api.sparkpost.com/api/v1/metrics/deliverability/time-series')
    params = { :from => config[:from], :precision => config[:precision], :metrics => config[:metrics] }
    uri.query = URI.encode_www_form(params)

    res = Net::HTTP.start(uri.host, uri.port,
      :use_ssl => uri.scheme == 'https') do |http|
      request = Net::HTTP::Get.new uri
      request.basic_auth config[:apikey], ''

      http.request(request)
    end

    case res
    when Net::HTTPSuccess
      # OK
    else
      warning 'Failed to query SparkPost API'
    end

    begin
      json = ::JSON.parse(res.body)
    rescue ::JSON::ParserError
      warning 'Failed to parse JSON'
    end

    json['results'].each do |results|
      date = DateTime.rfc3339(results['ts']).to_time.to_i
      results.delete('ts')
      results.each do |key, value|
        output "#{config[:scheme]}.#{key}", value, date
      end
    end

    ok

  end
end
