# Try nomad

In this project we start a Nomad cluster using Vagrant and deploy a few
services to it:

* A HAProxy reverse router
* A Docker registry
* A pair of HTTP services:
  * svc1, written in Haskell, squares the number passed in the request.
  * svc0, written in Kotlin, gets a number, passes it to svc1 and returns
    svc1's result.

## Requirements
* nix
  * If you don't use nix you'll have to install all dependencies manually
    and find a way to build the Haskell service docker image.

## Instructions
```bash
nix-shell


cd kotlin
docker build -t docker-registry.monoidmagma.com/svc0:latest .


cd haskell
nix-build docker.nix
NIX_PATH="nixpkgs=/nix/store/88fary4fmnwmd48killhi2icv7cgdjnr-nixpkgs-src" nix-build docker.nix

docker load < result

cd ..
vagrant up

nomad job run haproxy.nomad
nomad job run registry.nomad

echo "192.168.50.20 docker-registry.monoidmagma.com" | sudo tee --append /etc/hosts
echo "192.168.50.20 haproxy.monoidmagma.com" | sudo tee --append /etc/hosts
echo "192.168.50.20 numbers.monoidmagma.com" | sudo tee --append /etc/hosts


# point your browser to
# http://haproxy.monoidmagma.com:1936/
# http://192.168.50.10:4646
# http://192.168.50.2:8500/

curl -kv https://docker-registry.monoidmagma.com

docker push docker-registry.monoidmagma.com/svc1:latest
docker push docker-registry.monoidmagma.com/svc0:latest

nomad job run numbers.nomad

for i in $(seq 50); do curl -k "https://numbers.monoidmagma.com?n=$i"; echo; done

ab -n 1000 -c 50 'https://numbers.monoidmagma.com/?n=5555'

```

