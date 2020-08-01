#!/usr/bin/env ruby
# frozen_string_literal: true

# used put sandbox site under maninetance
# and restore it (dns switch)

require 'aws-sdk-route53'

# DNS records to be changed
records = ["record1", "record2"]
maintenance = "maintenance.demo.com"
type = "CNAME"

def get_dns_values (record, type)
  validate_type(type)
  client = Aws::Route53::Client.new(region: "us-east-1")

  resp = client.list_resource_record_sets(
    hosted_zone_id: "XXXXXXXXXXX", # required if of zone
    start_record_name: "#{record}.demo.com",
    start_record_type: type,
    max_items: 1,
  )

  resp.resource_record_sets[0].resource_records[0].value
end


def validate_type(type)
  suported_types = ["A", "TXT", "CNAME"]
  if !suported_types.include?(type)
    puts "Insert a correct type of record. Please select A, TXT or CNAME"
    exit 1
  end
end

def update_dns(record, type, value, action)
  validate_type(type)
  client = Aws::Route53::Client.new(region: "us-east-1")
  client.change_resource_record_sets(
    change_batch: {
      changes: [
      {
        action: action,
        resource_record_set: {
        name: "#{record}.demo.com",
        resource_records: [
          {
            value: "#{value}",
          },
          ],
          ttl: 1,
          type: type,
          },
      },
      ],
        comment: "dns record for maintenance",
    },
  hosted_zone_id: "XXXXXXXXXXX",
  )
  puts "dns record #{record}.demo.com updated"
end


## Perfrom action based on env variable
case ENV['ACTION']
when "MAINTENANCE"
  # Get dns records
  dns_original = Hash.new
  records.each { |record|
    dns_original[record] = get_dns_values(record, type)
  }

  # Backup records in TXT
  dns_original.each { |key, value|
      if value == maintenance
        puts "Records were already updated, Please run RESTORE instead"
        exit 1
      else
        update_dns(key + ".backup", "TXT", "\"#{value}\"", "UPSERT")
      end
    }

  # Update records to maintenance
  dns_original.each { |key, value|
    update_dns(key, type, maintenance, "UPSERT")
  }

when "RESTORE"
  # Read records from TXT
  dns_restore = Hash.new
  records.each { |record|
    dns_restore[record] = get_dns_values(record + ".backup", "TXT")
  }

  # Restore records
  dns_restore.each { |key, value|
    update_dns(key, type, value.gsub('"', ''), "UPSERT") # restore records
    update_dns(key + ".backup", "TXT", value, "DELETE") # delete TXT
  }

else
  puts "Unknown or missing ACTION environment variable."
  exit 1
end
