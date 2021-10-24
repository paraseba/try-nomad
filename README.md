# Try nomad

This is just me trying [Nomad](https://www.nomadproject.io/) and [Consul](https://www.consul.io/)
for the first time. Not much to see...

## References
* https://manicminer.io/posts/getting-started-with-hashicorp-nomad/ 
* https://www.nomadproject.io/docs


## The project
We have two trivial HTTP services, one written in Haskell (svc1) and one
written in Kotlin (svc0).

svc1 takes an HTTP request that includes an
`n` query parameter with a number, and returns the number squared
with 200 status.

svc0 does the same, except that instead of calculating the square itself
it forwards the number to svc0 and returns svc0's result.

### The "hardware"
We use four virtual machines (tested with VirtualBox) to simulate a
"cluster" where we will deploy Consul and Nomad. The VMs are started
using Vagrant and Ubuntu 18.04. A single vagrant file starts all
machines.

### The cluster
We create a cluster named `dc1` that includes:
* One VM for a Consul server
* One VM for a Nomad server
* Two VMs that are Nomad clients and Consul clients. These machines
  will also run our services svc0 and svc1.

The Machines have IPs:
* Consul server: 192.168.50.2
* Nomad server: 192.168.50.10
* Nomad client 1: 192.168.50.20
* Nomad client 2: 192.168.50.21

In various points we hardcode a fake domain name: monoidmagma.com.

### HAProxy
We also run HAProxy in the cluster, as a Nomad job, to be able to
terminate SSL and load balance access to the rest of the services.
To make it easy to access HAProxy, we run it always on Nomad client 1,
so it can be reached at 192.168.50.20.

The statistics page for HAProxy runs on port 1936.

A self-signed certificate is created on the fly for HAProxy, so testing
code must make sure to accept self-signed certificates.


### Docker Registry
We run a Docker registry in the cluster, as a Nomad job. The registry
has open access. For easy of access we also run the registry in the first
Nomad client machine.


## Requirements to run
This project was written and tested using [Nix](https://nixos.org/)
on a NixOS machine, but there is nothing that absolutely requires Nix.
But if you don't nix there are a few things you'll need to figure out
yourself:
* How to build and create a docker image for the Haskell project
* How to install all dependencies

The tools we use in the project are:
* vagrant
* VirtualBox
* nomad
* ab (apacheHttpd)
* docker
* docker-compose


## Instructions

### Build the services
For svc0:

```bash
cd kotlin
docker build -t docker-registry.monoidmagma.com/svc0:latest .
```

For svc1

```bash
cd haskell
nix-build docker.nix
docker load < result

# If you want a specific version of nixpath you can do
NIX_PATH="nixpkgs=/nix/store/88fary4fmnwmd48killhi2icv7cgdjnr-nixpkgs-src" nix-build docker.nix
```

### Start the virtual machines
In the root of the project run

```bash
vagrant up
```

This will take a while. You can verify by doing:
```bash
ping 192.168.50.2
ping 192.168.50.10
ping 192.168.50.20
ping 192.168.50.21
```

then navigating to:
* http://192.168.50.10:4646
* http://192.168.50.2:8500/

### Add hardcoded domain names
If you run nixos, in your configuration file add

```nix
networking.extraHosts = 
  ''
     192.168.50.20 docker-registry.monoidmagma.com
     192.168.50.20 haproxy.monoidmagma.com
     192.168.50.20 numbers.monoidmagma.com
     192.168.50.20 svc1.monoidmagma.com
     192.168.50.20 svc0.monoidmagma.com
  ''
```

If you don't use Nixos, just add those same domains to your /etc/hosts file.

### Run HAProxy
In the root of the repository run


```bash
nomad job run haproxy.nomad
```

You can verify it directing your browser to http://haproxy.monoidmagma.com:1936.


### Run the Docker registry
In the root of the repository run


```bash
nomad job run registry.nomad
```

Afte it finishes, if you do

```sh
curl https://docker-registry.monoidmagma.com
```
will fail because of the self-signed certificate. But if you try

```sh
curl -k https://docker-registry.monoidmagma.com
```
it should work.


### Push the docker images
```sh
docker push docker-registry.monoidmagma.com/svc0:latest
docker push docker-registry.monoidmagma.com/svc1:latest
```

### Run the services
```sh
nomad job run numbers.nomad
```

Check that the service works

```sh
for i in $(seq 50); do curl -k "https://numbers.monoidmagma.com?n=$i"; echo; done
```

and check performance with

```sh
ab -n 1000 -c 50 'https://numbers.monoidmagma.com/?n=5555'
```

