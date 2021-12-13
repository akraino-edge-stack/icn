# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'ipaddr'
require 'uri'
require 'yaml'

# IMPORTANT To bring up the machines, use the "--no-parallel" option
# to vagrant up.  This is to workaround dependencies between the jump
# machine and the machine pool machines.  Specifically, the pool
# machines will fail to come up until the baremetal network (created
# by vagrant from the jump machine definition) is up.

site = ENV['ICN_SITE'] || 'vm'

# Calculate the baremetal network address from the bmcAddress (aka
# IPMI address) specified in the machine pool values.  IPMI in the
# virtual environment is emulated by virtualbmc listening on the host.
baremetal_cidr = nil
Dir.glob("deploy/site/#{site}/*.yaml") do |file|
  YAML.load_stream(File.read(file)) do |document|
    values = document.fetch('spec', {}).fetch('values', {})
    next if values['machineName'].nil? || values['bootMACAddress'].nil?
    bmc_host = URI.parse(values['bmcAddress']).host
    baremetal_cidr = "#{IPAddr.new(bmc_host).mask(24)}/24"
  end
end
if baremetal_cidr.nil?
  puts "Missing bmcAddress value in site definition, can't determine baremetal network address"
  exit 1
end

$post_up_message = <<MSG
------------------------------------------------------

To get started with ICN:

  $ vagrant ssh jump
  vagrant@jump:~$ sudo su
  root@jump:/home/vagrant# cd /icn
  root@jump:/icn# make jump_server
  root@jump:/icn# make vm_cluster

------------------------------------------------------
MSG

#
# Networks
#
# The ICN baremetal network will be the vagrant management network.
# It is created automatically by vagrant.  The provisioning network
# will be a vagrant private network, and is required to be created by
# this script.  The IPMI network is created with virtualbmc.

#
# Machines
#
Vagrant.configure("2") do |config|
  # The jump machine
  config.vm.define 'jump' do |m|
    # Note the apparent typo in the name below, it is correct as-is
    m.vm.box = 'intergratedcloudnative/ubuntu1804'
    m.vm.box_version = '1.0.0'
    m.vm.hostname = 'jump'
    m.vm.synced_folder '.', '/icn'
    m.vm.provider :libvirt do |libvirt|
      libvirt.graphics_ip = '0.0.0.0'
      libvirt.default_prefix = "#{site}-"
      libvirt.cpu_mode = 'host-passthrough'
      libvirt.cpus = 8
      libvirt.memory = 24576
      libvirt.nested = true

      # The ICN baremetal network is the vagrant management network,
      # and is created by vagrant for us
      libvirt.management_network_name = "#{site}-baremetal"
      libvirt.management_network_address = baremetal_cidr
      libvirt.management_network_autostart = true
    end

    # The ICN provisioning network will be a vagrant private network
    # created upon bringing up the jump machine
    m.trigger.before [:up] do |trigger|
      trigger.name = 'Creating provisioning network'
      trigger.run = {inline: "./tools/vagrant/create_provisioning_network.sh #{site}"}
    end
    m.trigger.after [:destroy] do |trigger|
      trigger.name = 'Destroying provisioning network'
      trigger.run = {inline: "./tools/vagrant/destroy_provisioning_network.sh #{site}"}
    end
    m.vm.network :private_network,
                 :libvirt__network_name => "#{site}-provisioning",
                 :type => 'dhcp'

    # IPMI control of machines is provided by vbmc on the host
    m.trigger.after [:up] do |trigger|
      trigger.name = 'Starting virtualbmc for IPMI network'
      trigger.run = {inline: "./tools/vagrant/start_vbmc.sh"}
    end
    m.trigger.after [:destroy] do |trigger|
      trigger.name = 'Stopping virtualbmc for IPMI network'
      trigger.run = {inline: "./tools/vagrant/stop_vbmc.sh"}
    end

    m.trigger.after [:up] do |trigger|
      trigger.name = 'Creating ICN user_config.sh'
      trigger.run = {inline: "./tools/vagrant/create_user_config.sh"}
    end
    m.vm.provision 'Configuring ICN prerequisites', type: 'shell', privileged: true, inline: <<-SHELL
      ssh-keygen -f "${HOME}/.ssh/id_rsa" -P "" <<<y
      DEBIAN_FRONTEND=noninteractive apt-get install -y make
    SHELL
    m.vm.post_up_message = $post_up_message
  end

  # Look for any HelmReleases in the site directory with machineName in
  # the values dictionary.  This will provide the values needed to
  # create the machine pool.
  legacy_machine_args = ""
  Dir.glob("deploy/site/#{site}/*.yaml") do |file|
    YAML.load_stream(File.read(file)) do |document|
      values = document.fetch('spec', {}).fetch('values', {})
      next if values['machineName'].nil? || values['bootMACAddress'].nil?
      machine_name = values['machineName']
      boot_mac_address = values['bootMACAddress']
      bmc_port = URI.parse(values['bmcAddress']).port
      config.vm.define machine_name do |m|
        m.vm.hostname = machine_name
        m.vm.provider :libvirt do |libvirt|
          libvirt.graphics_ip = '0.0.0.0'
          libvirt.default_prefix = "#{site}-"
          libvirt.cpu_mode = 'host-passthrough'
          libvirt.cpus = 8
          libvirt.memory = 16384
          libvirt.nested = true
          # The image will be provisioned by ICN so just create an empty
          # disk for the machine
          libvirt.storage :file, :size => 50, :type => 'raw', :cache => 'none'
          # Management attach is false so that vagrant will not interfere
          # with these machines: the jump server will manage them
          # completely
          libvirt.mgmt_attach = false
        end
        # The provisioning network must be listed first for PXE boot to
        # the metal3/ironic provided image
        m.vm.network :private_network,
                     :libvirt__network_name => "#{site}-provisioning",
                     :mac => boot_mac_address,
                     :type => 'dhcp'
        m.vm.network :private_network,
                     :libvirt__network_name => "#{site}-baremetal",
                     :type => 'dhcp'

        # IPMI control
        m.trigger.after [:up] do |trigger|
          trigger.name = 'Adding machine to IPMI network'
          trigger.run = {inline: "./tools/vagrant/add_machine_to_vbmc.sh #{site} #{machine_name} #{bmc_port}"}
        end
        m.trigger.after [:destroy] do |trigger|
          trigger.name = 'Removing machine from IPMI network'
          trigger.run = {inline: "./tools/vagrant/remove_machine_from_vbmc.sh #{site} #{machine_name} #{bmc_port}"}
        end

        # Create configuration for ICN provisioning
        legacy_machine_args = "#{legacy_machine_args} #{machine_name} #{bmc_port}"
        m.trigger.after [:up] do |trigger|
          trigger.info = 'Creating nodes.json.sample describing the machines'
          trigger.run = {inline: "./tools/vagrant/create_nodes_json_sample.sh #{site} #{legacy_machine_args}"}
        end
        m.trigger.after [:up] do |trigger|
          trigger.info = 'Creating Provisioning resource describing the cluster'
          trigger.run = {inline: "./tools/vagrant/create_provisioning_cr.sh #{site} #{legacy_machine_args}"}
        end
      end
    end
  end
end
