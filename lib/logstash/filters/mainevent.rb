# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "logstash/json"
require "logstash/timestamp"

# This is a JSON parsing filter. It takes an existing field which contains JSON and
# expands it into an actual data structure within the Logstash event.
#
# By default it will place the parsed JSON in the root (top level) of the Logstash event, but this
# filter can be configured to place the JSON into any arbitrary event field, using the
# `target` configuration.
class LogStash::Filters::MainEvent < LogStash::Filters::Base

  config_name "mainevent"

  # The configuration for the JSON filter:
  # [source,ruby]
  #     source => source_field
  #
  # For example, if you have PHP serialized data in the `message` field:
  # [source,ruby]
  #     filter {
  #       mainevent {
  #         source => "message"
  #       }
  #     }
  #
  # The above would parse the php from the `message` field
  config :source, :validate => :string, :required => true

  # Define the target field for placing the parsed data. If this setting is
  # omitted, the PHP data will be stored at the root (top level) of the event.
  #
  # For example, if you want the data to be put in the `doc` field:
  # [source,ruby]
  #     filter {
  #       mainevent {
  #         target => "doc"
  #       }
  #     }
  #
  # JSON in the value of the `source` field will be expanded into a
  # data structure in the `target` field.
  #
  # NOTE: if the `target` field already exists, it will be overwritten!
  config :target, :validate => :string

  public
  def register
    # Nothing to do here
  end # def register

  public
  def filter(event)
    @logger.debug("Running mainevent filter", :event => event)

    return unless event.include?(@source)

    source = event[@source]

    begin
      # https://rubygems.org/gems/php-serialize/versions/1.1.0
      parsed = PHP.unserialize(source)
      # If your parsed JSON is an array, we can't merge, so you must specify a
      # destination to store the JSON, so you will get an exception about
      if parsed.kind_of?(Array) && @target.nil?
        raise('Parsed JSON arrays must have a destination in the configuration')
      elsif @target.nil?
        event.to_hash.merge! parsed
      else
        event[@target] = parsed
      end

      # If no target, we target the root of the event object. This can allow
      # you to overwrite @timestamp and this will typically happen for json
      # LogStash Event deserialized here.
      if !@target && event.timestamp.is_a?(String)
        event.timestamp = LogStash::Timestamp.parse_iso8601(event.timestamp)
      end

      filter_matched(event)
    rescue => e
      tag = "_phpparsefailure"
      event["tags"] ||= []
      event["tags"] << tag unless event["tags"].include?(tag)
      @logger.warn("Trouble parsing serialized", :source => @source,
                   :raw => event[@source], :exception => e)
      return
    end

    @logger.debug("Event after mainevent filter", :event => event)

  end # def filter

end # class LogStash::Filters::MainEvent
