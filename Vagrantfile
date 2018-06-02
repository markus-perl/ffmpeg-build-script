Vagrant.configure("2") do |config|

    # Every Vagrant virtual environment requires a box to build off of.
    config.vm.box = "mex_v7"
    config.vm.box_url = "http://static.wize.life/vagrant/debian-9-stretch-x64-slim.box"

    config.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--memory", "4096"]
        vb.customize ["modifyvm", :id, "--cpus", "4"]
        vb.customize ["modifyvm", :id, "--ostype", "Debian_64"]
        # vb.gui = true
    end

    config.vm.synced_folder ".", "/vagrant"

    config.ssh.insert_key=false

end
