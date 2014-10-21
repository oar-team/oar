# -*- mode: ruby -*-
# vi: set ft=ruby :

# Build your own debian base box :
#
# 1) Install kameleon
#    $ gem install kameleon-builder
#
# 2) Build a new vagrant box
#    a) For virtualbox users :
#    $ cd misc/kameleon/kameleon2
#    $ sudo kameleon build debian_oar_vagrant
#    $ vagrant box add 'oar-team/debian-oar-2.5' builds/debian_oar_vagrant/debian_oar_vagrant.box
#    $ sudo rm -rf builds
#
# 3) Up !
#    $ vagrant up

Vagrant.configure("2") do |config|
  config.vm.box = "oar-team/debian-oar-2.5"
  config.vm.hostname = "oar-devel"

  # share src folder with all nodes
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder ".", "/home/vagrant/oar", type: "rsync"

  # enable ssh forward agent for all VMs
  config.ssh.forward_agent = true
  config.vm.network "forwarded_port", guest: 80, host: 8080

  # Config provider
  config.vm.provider :virtualbox do |vm|
    vm.memory = 1024
    vm.cpus = 1
  end

  # proxy cache with polipo
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http = "http://10.10.10.1:8123/"
    config.proxy.https = "http://10.10.10.1:8123/"
    config.proxy.ftp = "http://10.10.10.1:8123/"
    config.proxy.no_proxy = "localhost,127.0.0.1"
    config.apt_proxy.http  = "http://10.10.10.1:8123/"
    config.apt_proxy.https = "http://10.10.10.1:8123/"
    config.apt_proxy.ftp = "http://10.10.10.1:8123/"
  end
end
