job "haproxy" {
  datacenters = ["dc1"]
  type        = "service"

  # we want to run haproxy in a specific node, to be able to route
  # DNS and make the TLS certificate available.
  constraint {
    attribute = "${meta.haproxy}"
    value = "true"
  }

  group "haproxy" {
    count = 1

    network {
      port "http" {
        static = 80
      }

      port "https" {
        static = 443
      }

      port "haproxy_ui" {
        static = 1936
      }
    }

    service {
      name = "haproxy"
      tags = [
        "http",
      ]

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }

      check {
        name     = "alive"
        type     = "tcp"
        port     = "https"
        interval = "10s"
        timeout  = "5s"
      }
    }

    task "haproxy" {
      driver = "docker"
      user = "root"
      config {

        image        = "haproxy:2.4"
        network_mode = "host"
        userns_mode  = "host"

        mount {
          type   = "bind"
          source = "local/haproxy.cfg"
          target = "/usr/local/etc/haproxy/haproxy.cfg"
        }
      }

      template {
        destination = "local/haproxy.cfg"
        change_mode = "restart"
        data        = <<EOF
global
   tune.ssl.default-dh-param 2048
   log stdout format raw local0 notice

defaults
   mode http
   timeout connect 5000
   timeout check 5000
   timeout client 30000
   timeout server 30000
   log global

frontend stats
   bind *:1936
   stats uri /
   stats show-legends
   no log

frontend http_front
   bind *:{{ env "NOMAD_PORT_http" }}
   bind *:{{ env "NOMAD_PORT_https" }} ssl crt /local/tls/monoidmagma.com/combined.pem
   http-request set-header X-Forwarded-Proto https if { ssl_fc }
   http-request redirect scheme https unless { ssl_fc }
{{ range $tag, $services := services | byTag }}{{ if eq $tag "proxy" }}{{ range $service := $services }}{{ if ne .Name "haproxy" }}
   acl host_{{ .Name }} hdr(host) -i {{ .Name }}.monoidmagma.com
   use_backend {{ .Name }} if host_{{ .Name }}
{{ end }}{{ end }}{{ end }}{{ end }}

{{ range $tag, $services := services | byTag }}{{ if eq $tag "proxy" }}{{ range $service := $services }}{{ if ne .Name "haproxy" }}
backend {{ .Name }}
    balance roundrobin
    server-template {{ .Name }} 1-10 _{{ .Name }}._tcp.service.consul resolvers consul resolve-opts allow-dup-ip resolve-prefer ipv4 check init-addr none
{{ end }}{{ end }}{{ end }}{{ end }}

resolvers consul
   nameserver consul 127.0.0.1:8600
   accepted_payload_size 8192
   hold valid 5s

EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }

      volume_mount {
        volume      = "certs"
        destination = "/local/tls"
        read_only   = true
      }
    }

    volume "certs" {
      type      = "host"
      read_only = true
      source    = "certs"
    }
  }
}
