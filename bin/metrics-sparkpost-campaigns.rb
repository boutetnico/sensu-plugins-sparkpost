#!/usr/bin/env ruby
#
#   metrics-sparkpost-campaigns
#
# DESCRIPTION:
#   Query SparkPost API for deliverability metrics by campaigns.
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

  option :to,
         short: '-t TO',
         long: '--to TO',
         description: 'Datetime in format of YYYY-MM-DDTHH:MM',
         default: ''

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
         default: 'sparkpost.campaigns'

  def run

    uri = URI('https://api.sparkpost.com/api/v1/metrics/deliverability/campaign')
    if config[:to].empty?
      params = { :from => config[:from], :precision => config[:precision], :metrics => config[:metrics] }
    else
      params = { :from => config[:from], :to => config[:to], :precision => config[:precision], :metrics => config[:metrics] }
      # date is either the value of provided config 'to'
      # or now if this option was not provided
      date = DateTime.parse(config[:to]).to_time.to_i
    end
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
      campaign = results['campaign_id'].gsub(/[^0-9a-z ]/i, '_')
      results.delete('campaign_id')
      results.each do |key, value|
        if config[:to].empty?
          output "#{config[:scheme]}.#{campaign}.#{key}", value
        else
          output "#{config[:scheme]}.#{campaign}.#{key}", value, date
        end
      end
    end

    ok

  end
end
