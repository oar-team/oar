# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "oar_devel_git2debian"
  config.vm.box_url = "http://oar.quicker.fr/vagrant/oar_devel_git2debian.box"
  # shared folders
  config.vm.synced_folder ".", "/home/vagrant/oar", type: "nfs"
  # Config provider
  config.vm.provider :virtualbox do |vm|
    vm.memory = 512
    vm.cpus = 1
  end
end
