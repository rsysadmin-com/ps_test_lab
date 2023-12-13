Vagrant.configure("2") do |config|
  config.vm.define "DOMAIN"
  config.vm.box = "generic/ubuntu2004"

  config.vm.provider :libvirt do |libvirt|
    libvirt.memory = 8192 # 8 GB RAM
    libvirt.cpus = 4 # 4 vCPUs
  end

  #config.vm.network "private_network", type: "dhcp"
  config.vm.network "private_network", type: "static", ip: "192.168.121.150"
  config.vm.provision "shell", path: "ps_bootstrap.sh", :args => "'DOMAIN.TLD'"
end
