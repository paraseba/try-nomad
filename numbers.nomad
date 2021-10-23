job "numbers" {
  datacenters = ["dc1"]
  type        = "service"

  group "svc1" {
    count = 1

    network {
      mode = "bridge"
      port "http" { }
    }

    service {
      name = "svc1"

      # this doesn't work, see https://github.com/hashicorp/nomad/issues/9907
      #port = "http"

      port = "8080"
      tags = [
        "http",
      ]

      connect {
        sidecar_service { }
      }

      check {
        type     = "http"
        expose   = true
        name     = "svc1 http"
        path     = "/"
        port     = "http"
        interval = "10s"
        timeout  = "5s"
      }
    }

    task "svc1" {
      driver = "docker"

      config {
        image = "docker-registry.monoidmagma.com/svc1:latest"
      }

      resources {
        cpu    = 500
        memory = 48
      }
    }
  } # ------------------ svc1 -------------------


  group "numbers" {
    count = 2

    network {
      mode = "bridge"
      port "http" {
        to = 8081
      }
    }

    service {
      name = "numbers"
      port = "http"
      tags = [
        "http",
        "proxy",
      ]

      connect {
        sidecar_service {
          # we don't want to proxy through haproxy
          tags = ["http"]
          proxy {
            upstreams {
              destination_name = "svc1"
              local_bind_port  = 5000
            }
          }
        }
      }

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "5s"
      }
    }

    task "svc0" {
      driver = "docker"

      env {
        SVC1_URL = "http://${NOMAD_UPSTREAM_ADDR_svc1}"
      }

      config {
        image = "docker-registry.monoidmagma.com/svc0:latest"
      }

      resources {
        cpu    = 1000
        memory = 128
      }
    }
  } # ------------------ numbers  -------------------
}
