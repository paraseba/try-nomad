# -*- mode: ruby -*-
# vi: set ft=ruby :


$apt_script = <<SCRIPT
echo "Setting up APT..."
sudo apt-get update
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
SCRIPT

$docker_script = <<SCRIPT
echo "Installing docker..."
sudo apt-get remove docker docker-engine docker.io
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable"
sudo apt-get update
sudo apt-get install -y docker-ce
echo '{"insecure-registries" : [ "docker-registry.monoidmagma.com" ]}' | sudo tee /etc/docker/daemon.json
# Restart docker to make sure we get the latest version of the daemon if there is an upgrade
sudo service docker restart
# Make sure we can actually use docker as the vagrant user
sudo usermod -aG docker vagrant
sudo docker --version
SCRIPT

$cni_script = <<SCRIPT
  curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v1.0.1.tgz
  sudo mkdir -p /opt/cni/bin
  sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz

  echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-arptables
  echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-ip6tables
  echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables

  (
  cat <<-EOF
    net.bridge.bridge-nf-call-arptables = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
EOF
  ) | sudo tee /etc/sysctl.d/30-bridge-cni-plugins.conf
SCRIPT

$consul_script = <<SCRIPT
echo "Installing dependencies..."
sudo apt-get install unzip curl vim -y

cd /tmp/

echo "Installing Consul..."
CONSUL_VERSION=1.10.3
curl -sSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip > consul.zip
unzip /tmp/consul.zip
sudo install consul /usr/bin/consul
sudo mkdir -p /opt/consul-data

for bin in cfssl cfssl-certinfo cfssljson
do
  echo "Installing $bin..."
  curl -sSL https://pkg.cfssl.org/R1.2/${bin}_linux-amd64 > /tmp/${bin}
  sudo install /tmp/${bin} /usr/local/bin/${bin}
done
SCRIPT


def consul_server_script(my_ip)
  return <<-SCRIPT
  (
  cat <<-EOF
    {
      "server": true,
      "bootstrap": true,
      "ui_config": {    "enabled": true  },
      "datacenter": "dc1",
      "data_dir": "/opt/consul-data",
      "log_level": "INFO",
      "addresses": {    "http": "0.0.0.0"  },
      "bind_addr": "#{my_ip}",
      "connect": {    "enabled": true  }
    }
EOF
  ) | sudo tee /etc/consul-server.json

  (
  cat <<-EOF
    [Unit]
    Description=consul agent
    Requires=network-online.target
    After=network-online.target

    [Service]
    Restart=on-failure
    ExecStart=/usr/bin/consul agent -config-file=/etc/consul-server.json
    ExecReload=/bin/kill -HUP $MAINPID

    [Install]
    WantedBy=multi-user.target
EOF
  ) | sudo tee /etc/systemd/system/consul.service
  sudo systemctl enable consul.service
  sudo systemctl start consul
  SCRIPT
end

def consul_client_script(my_ip, server_ips)
  sips = server_ips.map {|ip| "\"#{ip}\""}.join(", ")
  return <<-SCRIPT
  (
  cat <<-EOF
    {
      "server": false,
      "datacenter": "dc1",
      "data_dir": "/opt/consul-data",
      "log_level": "INFO",
      "bind_addr": "#{my_ip}",
      "retry_join": [#{sips}],
      "ports": {
        "grpc": 8502
      }
    }
EOF
  ) | sudo tee /etc/consul-client.json

  (
  cat <<-EOF
    [Unit]
    Description=consul agent
    Requires=network-online.target
    After=network-online.target

    [Service]
    Restart=on-failure
    ExecStart=/usr/bin/consul agent -config-file=/etc/consul-client.json
    ExecReload=/bin/kill -HUP $MAINPID

    [Install]
    WantedBy=multi-user.target
EOF
  ) | sudo tee /etc/systemd/system/consul.service
  sudo systemctl enable consul.service
  sudo systemctl start consul
  SCRIPT
end

$nomad_script = <<SCRIPT
echo "Installing Nomad..."
NOMAD_VERSION=1.1.6
cd /tmp/
curl -sSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip -o nomad.zip
unzip nomad.zip
sudo install nomad /usr/bin/nomad
sudo mkdir -p /etc/nomad.d
sudo chmod a+w /etc/nomad.d
SCRIPT


def nomad_server_script(my_ip, expect)
  return <<-SCRIPT
  sudo mkdir -p /opt/nomad/data

  (
  cat <<-EOF
  # /etc/nomad.d/server.hcl
  # data_dir tends to be environment specific.

  data_dir = "/opt/nomad/data"
  datacenter = "dc1"
  server {
    enabled          = true
    bootstrap_expect = #{expect}
  }

  advertise {
    http = "#{my_ip}"
    rpc = "#{my_ip}"
    serf = "#{my_ip}"
  }

  telemetry {
    publish_allocation_metrics = true
    publish_node_metrics       = true
    prometheus_metrics         = true
 }
EOF
  ) | sudo tee /etc/nomad.d/server.hcl

  (
  cat <<-EOF
    [Unit]
    Description=nomad agent
    Documentation=https://www.nomadproject.io/docs/
    Requires=network-online.target
    Wants=network-online.target
    After=network-online.target
    Wants=consul.service
    After=consul.service


    [Service]
    ExecReload=/bin/kill -HUP $MAINPID
    ExecStart=/usr/bin/nomad agent -config /etc/nomad.d
    KillMode=process
    KillSignal=SIGINT
    LimitNOFILE=65536
    LimitNPROC=infinity
    Restart=on-failure
    RestartSec=2

    TasksMax=infinity
    OOMScoreAdjust=-1000

    [Install]
    WantedBy=multi-user.target
EOF
  ) | sudo tee /etc/systemd/system/nomad.service
  sudo systemctl enable nomad.service
  sudo systemctl start nomad

  SCRIPT
end

def nomad_meta(opts)
  "meta {\n" +
    opts.map {|k,v| "\t#{k} = \"#{v}\""}.join("\n") +
    "\n}"
end


def nomad_client_script(my_ip, meta)
  return <<-SCRIPT
  sudo mkdir -p /opt/nomad/data
  sudo mkdir -p /etc/certs
  sudo mkdir -p /opt/registry/data

  (
  cat <<-EOF
  # /etc/nomad.d/client.hcl
  datacenter = "dc1"
  data_dir = "/opt/nomad/data"
  client {
    enabled = true
    network_interface = "eth1"

    host_volume "certs" {
      path      = "/etc/certs"
      read_only = true
    }

    host_volume "registry" {
      path      = "/opt/registry/data"
      read_only = false
    }

    #{nomad_meta(meta)}
  }

  advertise {
    http = "#{my_ip}"
    rpc = "#{my_ip}"
    serf = "#{my_ip}"
  }

  telemetry {
    publish_allocation_metrics = true
    publish_node_metrics       = true
    prometheus_metrics         = true
  }
EOF
  ) | sudo tee /etc/nomad.d/client.hcl

  (
  cat <<-EOF
    [Unit]
    Description=nomad agent
    Documentation=https://www.nomadproject.io/docs/
    Requires=network-online.target
    Wants=network-online.target
    After=network-online.target
    Wants=consul.service
    After=consul.service


    [Service]
    ExecReload=/bin/kill -HUP $MAINPID
    ExecStart=/usr/bin/nomad agent -config /etc/nomad.d
    KillMode=process
    KillSignal=SIGINT
    LimitNOFILE=65536
    LimitNPROC=infinity
    Restart=on-failure
    RestartSec=2

    TasksMax=infinity
    OOMScoreAdjust=-1000

    [Install]
    WantedBy=multi-user.target
EOF
  ) | sudo tee /etc/systemd/system/nomad.service
  sudo systemctl enable nomad.service
  sudo systemctl start nomad
  SCRIPT
end


consul_server_ip = "192.168.50.2"
consul_server_ips = [consul_server_ip]
nomad_server_ip = "192.168.50.10"

def nomad_client_ip(i)
  "192.168.50.#{20 + i}"
end


Vagrant.configure(2) do |config|
  config.vm.box = "bento/ubuntu-18.04" # 18.04 LTS
  config.vm.provision "shell", inline: $apt_script, privileged: false
  config.vm.provision "shell", inline: $consul_script, privileged: false

  # Increase memory for Virtualbox
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
  end

  # Increase memory for Parallels Desktop
  config.vm.provider "parallels" do |p, o|
    p.memory = "1024"
  end

  # Increase memory for VMware
  ["vmware_fusion", "vmware_workstation"].each do |p|
    config.vm.provider p do |v|
      v.vmx["memsize"] = "1024"
    end
  end


  config.vm.define "consul-server-0" do |node|
    node.vm.hostname = "consul-server-0"
    node.vm.provision "shell", inline: consul_server_script(consul_server_ip), privileged: false
    node.vm.network "forwarded_port", guest: 8500, host: 8500, auto_correct: true, host_ip: "127.0.0.1"
    node.vm.network "private_network", ip: consul_server_ip, hostname: true
  end

  config.vm.define "nomad-server-0" do |node|
    node.vm.hostname = "nomad-server-0"
    node.vm.provision "shell", inline: consul_client_script(nomad_server_ip, consul_server_ips), privileged: false
    node.vm.provision "shell", inline: $nomad_script, privileged: false
    node.vm.provision "shell", inline: nomad_server_script(nomad_server_ip, 1), privileged: false

    node.vm.network "private_network", ip: nomad_server_ip, hostname: true
    node.vm.network "forwarded_port", guest: 4646, host: 4646, auto_correct: true, host_ip: "127.0.0.1"
  end

  (0..1).each do |i|
    config.vm.define "nomad-client-#{i}" do |node|
      node.vm.hostname = "nomad-client-#{i}"
      node.vm.network "private_network", ip: nomad_client_ip(i), hostname: true
      node.vm.provision "shell", inline: $docker_script, privileged: false
      node.vm.provision "shell", inline: $cni_script, privileged: false
      node.vm.provision "shell", inline: consul_client_script(nomad_client_ip(i), consul_server_ips), privileged: false
      node.vm.provision "shell", inline: $nomad_script, privileged: false
      meta = i == 0 ? {haproxy: true} : {}
      node.vm.provision "shell", inline: nomad_client_script(nomad_client_ip(i), meta), privileged: false

      # include the TLS certificate for HAProxy
      if i==0
        node.vm.provision "shell", privileged: false, inline: <<-EOF
          openssl req \
            -nodes -x509 \
            -newkey rsa:4096 \
            -days 365 \
            -addext "subjectAltName = DNS:*.monoidmagma.com" \
            -subj "/C=US/ST=Oregon/L=Portland/O=MonoidMagma/OU=Org/CN=*.monoidmagma.com" \
            -keyout /tmp/key.pem \
            -out /tmp/cert.pem

          sudo mkdir -p /etc/certs/monoidmagma.com
          cat /tmp/key.pem /tmp/cert.pem | sudo tee /etc/certs/monoidmagma.com/combined.pem
          sudo chmod o+r /etc/certs/monoidmagma.com/combined.pem
        EOF
      end

      node.vm.provision "shell", inline: <<-EOF
        echo "\n#{nomad_client_ip(0)} docker-registry.monoidmagma.com" >> /etc/hosts
      EOF

    end
  end

end
