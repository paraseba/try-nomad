job "docker-registry" {
  datacenters = ["dc1"]

  type = "service"

  group "registry" {
    count = 1

    network {
      port "http" {
        to = 5000
      }
    }

    service {
      name = "docker-registry"
      port = "http"
      tags = [
        "http",
        "proxy",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "registry" {
      driver = "docker"

      config {
          image = "registry:2"
          ports = ["http"]
        }

      volume_mount {
        volume      = "registry"
        destination = "/var/lib/registry"
        read_only   = false
      }
    }

    volume "registry" {
      type      = "host"
      read_only = false
      source    = "registry"
    }
  }
}
