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
#    $ sudo kameleon build debian_vagrant
#    $ vagrant box add 'debian7-oar' builds/debian_vagrant/debian_vagrant.box
#    $ sudo rm -rf builds
#    
#    b) For libvirt users :
#    $ cd misc/kameleon/kameleon2
#    $ sudo kameleon build debian_vagrant_libvirt
#    $ vagrant box add 'debian7-oar' builds/debian_vagrant_libvirt/debian_vagrant_libvirt.box
#    $ sudo rm -rf builds
#
# 3) Up !
#    $ vagrant up --provider=[virtualbox|libvirt]
# 
# Note: In order to use vagrant with libvirt, you need to install vagrant-libvirt plugin first !
#    $ vagrant plugin install vagrant-libvirt


NFS_OPTS = ["rw","all_squash","anonuid=1000","anongid=1000","async", "no_subtree_check"]

NODE_AMOUNT = 2
CORE_PER_NODE = 2

Vagrant.configure("2") do |config|
  config.vm.box = "debian7-oar"

  # share src folder with all nodes
  config.vm.synced_folder ".", "/vagrant", type: "nfs", disabled: true
  config.vm.synced_folder ".", "/home/vagrant/oar", type: "nfs", linux__nfs_options: NFS_OPTS

  # enable ssh forward agent for all VMs
  config.ssh.forward_agent = true

  # Nodes definitions
  (1..NODE_AMOUNT).each do |i|
    config.vm.define "node#{i}" do |node|
      # networking options
      node.vm.hostname = "node#{i}"
      node.vm.network :private_network, ip: "10.10.10.10#{i}"
      node.vm.provision "shell", privileged: true, path: "misc/vagrant/install_node.sh"
    end
  end

 # Server
  config.vm.define "frontend" do |frontend|
    # networking options
    frontend.vm.hostname = "frontend"
    frontend.vm.network :private_network, ip: "10.10.10.100"
    frontend.vm.provision "shell", privileged: true, path: "misc/vagrant/install_frontend.sh"
  end

  # Server
  config.vm.define "server" do |server|
    # networking options
    server.vm.hostname = "server"
    server.vm.network :private_network, ip: "10.10.10.99"
    server.vm.provision "shell", privileged: true, path: "misc/vagrant/install_server.sh"

    script = <<-EOF
      # Configure oar
      oarproperty -a core
      oarproperty -a cpu
    EOF
    # oar node setting
    (1..NODE_AMOUNT).each do |i|
      (0..(CORE_PER_NODE - 1)).each do |c|
        core_id = ((i - 1) * CORE_PER_NODE) + c
        script << "oarnodesetting -a -h node#{i} -p cpu=#{i - 1} -p core=#{core_id} -p cpuset=0\n"
      end
    end
    server.vm.provision "shell", privileged: true, inline: script
  end

  # Config provider
  config.vm.provider :virtualbox do |vm|
    vm.memory = 512
    vm.cpus = 1
  end

  config.vm.provider :libvirt do |domain|
    domain.memory = 512
    domain.cpus = 1
  end

  # proxy cache with polipo
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http = "http://10.10.10.1:8123/"
    config.proxy.https = "http://10.10.10.1:8123/"
    config.proxy.ftp = "http://10.10.10.1:8123/"
    config.proxy.no_proxy = "localhost,127.0.0.1"
    config.env_proxy.http = "http://10.10.10.1:8123/"
    config.env_proxy.https = "http://10.10.10.1:8123/"
    config.env_proxy.ftp = "http://10.10.10.1:8123/"
    config.env_proxy.no_proxy = "localhost,127.0.0.1"
    config.apt_proxy.http  = "http://10.10.10.1:8123/"
    config.apt_proxy.https = "http://10.10.10.1:8123/"
    config.apt_proxy.ftp = "http://10.10.10.1:8123/"
  end
end
