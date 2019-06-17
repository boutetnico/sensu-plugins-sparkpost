#!/usr/bin/env ruby
#
#   metrics-sparkpost-usage
#
# DESCRIPTION:
#   Query SparkPost API for account quota usage metrics.
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

class SparkpostUsageMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :apikey,
         short: '-k APIKEY',
         long: '--apikey APIKEY',
         description: 'Your SparkPost API Key',
         required: true

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         required: true,
         default: 'sparkpost.usage'

  def run

    uri = URI('https://api.sparkpost.com/api/v1/account?include=usage')

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

    usage = json['results']['usage']

    date = DateTime.rfc3339(usage['timestamp']).to_time.to_i
    output "#{config[:scheme]}.day.used", usage['day']['used'], date
    output "#{config[:scheme]}.day.limit", usage['day']['limit'], date
    output "#{config[:scheme]}.month.used", usage['month']['used'], date
    output "#{config[:scheme]}.month.limit", usage['month']['limit'], date

    ok

  end
end
