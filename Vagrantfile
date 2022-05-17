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
with_jenkins = ENV['WITH_JENKINS'] || false

# Calculate the baremetal network address from the bmcAddress (aka
# IPMI address) specified in the machine pool values.  IPMI in the
# virtual environment is emulated by virtualbmc listening on the host.
baremetal4_gw = '192.168.151.1'
baremetal4_netmask = '255.255.255.0'
baremetal6_gw = nil
baremetal6_prefix = nil
bmc_host = '192.168.121.1' # From the default vagrant-libvirt network
registry_mirrors = nil
Dir.glob("deploy/site/#{site}/deployment/*.yaml") do |file|
  YAML.load_stream(File.read(file)) do |document|
    values = document.fetch('spec', {}).fetch('values', {})
    unless values['networkData'].nil? or values['networkData']['networks'].nil?
      networks = values['networkData']['networks']
      unless networks['ipv4'].nil?
        networks['ipv4'].select {|name,network| network.fetch('link', name) == 'baremetal'}.each_value do |network|
          if network.key?('gateway')
            baremetal4_gw = network['gateway']
          elsif network.key?('fromIPPool')
            pool = network['fromIPPool']
            if values['ipPools']["#{pool}"].key?('gateway')
              baremetal4_gw = values['ipPools']["#{pool}"]['gateway']
            end
          end
        end
      end
      unless networks['ipv6'].nil?
        networks['ipv6'].select {|name,network| network.fetch('link', name) == 'baremetal'}.each_value do |network|
          if network.key?('gateway')
            baremetal6_gw = network['gateway']
            baremetal6_prefix = 64
          elsif network.key?('fromIPPool')
            pool = network['fromIPPool']
            if values['ipPools']["#{pool}"].key?('gateway')
              baremetal6_gw = values['ipPools']["#{pool}"]['gateway']
              baremetal6_prefix = 64
            end
          end
        end
      end
    end
    unless values['bmcAddress'].nil?
      bmc_host = URI.parse(values['bmcAddress']).host
    end
    unless values['dockerRegistryMirrors'].nil?
      registry_mirrors = values['dockerRegistryMirrors'].join(' ')
    end
  end
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
    m.vm.box = 'intergratedcloudnative/ubuntu2004'
    m.vm.hostname = 'jump'
    m.vm.synced_folder '.', '/icn', type: 'nfs'
    m.vm.provider :libvirt do |libvirt|
      libvirt.graphics_ip = '0.0.0.0'
      libvirt.default_prefix = "#{site}-"
      libvirt.cpu_mode = 'host-passthrough'
      if with_jenkins
        # With Jenkins and nested VMs increase cpus, memory
        libvirt.cpus = 32
        libvirt.memory = 65536
      else
        libvirt.cpus = 8
        libvirt.memory = 24576
      end
      libvirt.nested = true
    end

    # The ICN baremetal network will be a vagrant private network
    # created upon bringing up the jump machine
    m.trigger.before [:up] do |trigger|
      trigger.name = 'Creating baremetal network'
      trigger.run = {inline: "./tools/vagrant/create_baremetal_network.sh #{site} #{baremetal4_gw} #{baremetal4_netmask} #{baremetal6_gw} #{baremetal6_prefix}"}
    end
    m.trigger.after [:destroy] do |trigger|
      trigger.name = 'Destroying baremetal network'
      trigger.run = {inline: "./tools/vagrant/destroy_baremetal_network.sh #{site}"}
    end
    m.vm.network :private_network,
                 :libvirt__network_name => "#{site}-baremetal",
                 :type => 'dhcp'

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

    # BMC control of machines is provided by sushy-emulator on the host
    m.trigger.after [:up] do |trigger|
      trigger.name = 'Starting sushy for BMC network'
      trigger.run = {inline: "./tools/vagrant/start_sushy.sh #{bmc_host}"}
    end
    m.trigger.after [:destroy] do |trigger|
      trigger.name = 'Stopping sushy for BMC network'
      trigger.run = {inline: "./tools/vagrant/stop_sushy.sh #{bmc_host}"}
    end

    m.trigger.after [:up] do |trigger|
      trigger.name = 'Creating ICN user_config.sh'
      trigger.run = {inline: "bash -c 'DOCKER_REGISTRY_MIRRORS=\"#{registry_mirrors}\" ./tools/vagrant/create_user_config.sh'"}
    end
    m.vm.provision 'Configuring ICN prerequisites', type: 'shell', privileged: true, inline: <<-SHELL
      ssh-keygen -f "${HOME}/.ssh/id_rsa" -P "" <<<y
      DEBIAN_FRONTEND=noninteractive apt-get install -y make
    SHELL
    m.vm.post_up_message = $post_up_message

    if with_jenkins
      # Set up a port forward for an instance of Jenkins
      m.vm.network "forwarded_port", guest: 8080, host: 8080
    end
  end

  # Look for any HelmReleases in the site directory with machineName in
  # the values dictionary.  This will provide the values needed to
  # create the machine pool.
  legacy_machine_args = ""
  Dir.glob("deploy/site/#{site}/deployment/*.yaml") do |file|
    YAML.load_stream(File.read(file)) do |document|
      values = document.fetch('spec', {}).fetch('values', {})
      next if values['machineName'].nil? || values['bootMACAddress'].nil?
      machine_name = values['machineName']
      boot_mac_address = values['bootMACAddress']
      baremetal_mac_address = nil
      if values['networkData'] and
          values['networkData']['links'] and
          values['networkData']['links']['ethernets'] and
          values['networkData']['links']['ethernets']['baremetal'] and
          baremetal_mac_address = values['networkData']['links']['ethernets']['baremetal']['macAddress']
      end
      bmc_port = URI.parse(values['bmcAddress']).port
      uuid = URI.parse(values['bmcAddress']).path.split('/').last
      config.vm.define machine_name do |m|
        m.vm.hostname = machine_name
        m.vm.provider :libvirt do |libvirt|
          libvirt.uuid = "#{uuid}"
          libvirt.graphics_ip = '0.0.0.0'
          libvirt.default_prefix = "#{site}-"
          libvirt.cpu_mode = 'host-passthrough'
          libvirt.cpus = 8
          libvirt.memory = 16384
          libvirt.nested = true
          # The image will be provisioned by ICN so just create an empty
          # disk for the machine
          libvirt.storage :file, :size => 50, :type => 'raw', :cache => 'none'
          # Create an additional disk for cStor
          libvirt.storage :file, :size => 16, :type => 'raw', :cache => 'none'
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
        if baremetal_mac_address.nil?
          m.vm.network :private_network,
                       :libvirt__network_name => "#{site}-baremetal",
                       :type => 'dhcp'
        else
          m.vm.network :private_network,
                       :libvirt__network_name => "#{site}-baremetal",
                       :mac => baremetal_mac_address,
                       :type => 'dhcp'
        end
      end
    end
  end
end
