#!/usr/bin/env ruby
require 'yaml'

site = ENV['ICN_SITE'] || 'vm'

Dir.chdir(File.join(__dir__, '../../'))
system('vagrant destroy -f jump')

Dir.glob("deploy/site/#{site}/*.yaml") do |file|
  YAML.load_stream(File.read(file)) do |document|
    values = document.fetch('spec', {}).fetch('values', {})
    next if values['machineName'].nil? || values['bootMACAddress'].nil?
    machine_name = values['machineName']
    system("virsh -c qemu:///system destroy vm-#{machine_name}")
    system("virsh -c qemu:///system undefine --nvram --remove-all-storage vm-#{machine_name}")
  end
end
