#!/usr/bin/env ruby
require 'yaml'

site = ENV['ICN_SITE'] || 'vm'

Dir.chdir(File.join(__dir__, '../../'))
system("virsh -c qemu:///system destroy #{site}-jump")
system("virsh -c qemu:///system undefine --nvram --remove-all-storage #{site}-jump")

Dir.glob("deploy/site/#{site}/deployment/*.yaml") do |file|
  YAML.load_stream(File.read(file)) do |document|
    values = document.fetch('spec', {}).fetch('values', {})
    next if values['machineName'].nil? || values['bootMACAddress'].nil?
    machine_name = values['machineName']
    system("virsh -c qemu:///system destroy #{site}-#{machine_name}")
    system("virsh -c qemu:///system undefine --nvram --remove-all-storage #{site}-#{machine_name}")
  end
end
