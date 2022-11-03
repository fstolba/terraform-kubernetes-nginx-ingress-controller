// https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.29.0/deploy/static/mandatory.yaml
resource "kubernetes_namespace" "nginx" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = var.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name      = "${var.name}-config-map"
    namespace = kubernetes_namespace.nginx.metadata.0.name

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = var.nginx_config
}

resource "kubernetes_config_map" "nginx_tcp" {
  metadata {
    name      = "${var.name}-tcp-services"
    namespace = kubernetes_namespace.nginx.metadata.0.name

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  data = local.tcp_services_map

}

resource "kubernetes_config_map" "nginx_udp" {
  metadata {
    name      = "${var.name}-udp-services"
    namespace = kubernetes_namespace.nginx.metadata.0.name

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = local.udp_services_map
}

resource "kubernetes_service_account" "nginx" {
  metadata {
    name      = "${var.name}-serviceaccount"
    namespace = kubernetes_namespace.nginx.metadata.0.name

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_cluster_role" "nginx" {
  metadata {
    name = "${var.name}-clusterrole"

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "endpoints", "nodes", "pods", "secrets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses/status"]
    verbs      = ["update"]
  }
}

resource "kubernetes_role" "nginx" {
  metadata {
    name      = "${var.name}-role"
    namespace = kubernetes_namespace.nginx.metadata.0.name

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "pods", "secrets", "namespaces"]
    verbs      = ["get"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["${var.name}-leader"]
    verbs          = ["get", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["endpoints"]
    verbs      = ["get"]
  }
}

resource "kubernetes_role_binding" "nginx" {
  metadata {
    name      = "${var.name}-role-binding"
    namespace = kubernetes_namespace.nginx.metadata.0.name

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.nginx.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.nginx.metadata.0.name
    namespace = kubernetes_service_account.nginx.metadata.0.namespace
  }
}

resource "kubernetes_cluster_role_binding" "nginx" {
  metadata {
    name = "${var.name}-clusterrole-binding"

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.nginx.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.nginx.metadata.0.name
    namespace = kubernetes_service_account.nginx.metadata.0.namespace
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "${var.name}-deployment"
    namespace = kubernetes_namespace.nginx.metadata.0.name

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/version"    = "v${var.nginx_ingress_controller_version}"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    replicas = var.controller_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"    = var.name
        "app.kubernetes.io/part-of" = kubernetes_namespace.nginx.metadata.0.name
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"    = var.name
          "app.kubernetes.io/part-of" = kubernetes_namespace.nginx.metadata.0.name
          "app.kubernetes.io/version" = "v${var.nginx_ingress_controller_version}"
        }

        annotations = {
          "prometheus.io/port"   = "10254"
          "prometheus.io/scrape" = "true"
          // TODO make these configurable
          "nginx.ingress.kubernetes.io/server-snippet" = "grpc_read_timeout 3600s;"
        }
      }

      spec {
        // wait up to 2 minutes to drain connections
        termination_grace_period_seconds = 100
        service_account_name             = kubernetes_service_account.nginx.metadata.0.name
        priority_class_name              = var.priority_class_name

        node_selector = {
          "kubernetes.io/os" = "linux",
          # "node.kubernetes.io/lifecycle"="on-demand"
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              topology_key = "kubernetes.io/hostname"
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [var.name]
                }
              }
            }
          }
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 1
              preference {
                match_expressions {
                  key      = "restart"
                  operator = "In"
                  values   = ["unlikely"]
                }
              }
            }
          }
        }
        # topologySpreadConstraints do same, but not implemented in terraform v0.14.3 yet.
        # topologySpreadConstraints:
        #   - labelSelector:
        #       matchLabels:
        #         app.kubernetes.io/name: ingress-nginx
        #     maxSkew: 1
        #     topologyKey: kubernetes.io/hostname


        toleration {
          effect   = "NoSchedule"
          key      = "onlyfor"
          operator = "Equal"
          value    = "highcpu"
        }
        toleration {
          effect   = "NoSchedule"
          key      = "dbonly"
          operator = "Equal"
          value    = "yes"
        }

        container {
          name  = "nginx-ingress-controller"
          image = "registry.k8s.io/ingress-nginx/controller:${var.nginx_ingress_controller_version}"

          args = [
            "/nginx-ingress-controller",
            "--configmap=$(POD_NAMESPACE)/${kubernetes_config_map.nginx_config.metadata.0.name}",
            "--tcp-services-configmap=$(POD_NAMESPACE)/${kubernetes_config_map.nginx_tcp.metadata.0.name}",
            "--udp-services-configmap=$(POD_NAMESPACE)/${kubernetes_config_map.nginx_udp.metadata.0.name}",
            "--publish-service=$(POD_NAMESPACE)/${var.name}",
            "--enable-ssl-chain-completion=true",
            # "--enable-ssl-passthrough",
            "--election-id=${var.name}-leader",
            "--ingress-class=${var.class_name}",
            "--default-ssl-certificate=${var.tls_secret_name}",
          ]

          # volume_mount {
          #   mount_path = "/var/run/secrets/kubernetes.io/serviceaccount"
          #   name       = kubernetes_service_account.nginx.default_secret_name
          #   read_only  = true
          # }

          security_context {
            allow_privilege_escalation = true
            run_as_user                = 101
            capabilities {
              drop = ["ALL"]
              add  = ["NET_BIND_SERVICE"]
            }
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          port {
            name           = "https"
            container_port = 443
            protocol       = "TCP"
          }

          liveness_probe {
            failure_threshold = 3
            http_get {
              path   = "/healthz"
              port   = 10254
              scheme = "HTTP"
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 10
            success_threshold     = 1
          }

          readiness_probe {
            failure_threshold = 3
            http_get {
              path   = "/healthz"
              port   = 10254
              scheme = "HTTP"
            }

            period_seconds    = 10
            timeout_seconds   = 10
            success_threshold = 1
          }

          lifecycle {
            pre_stop {
              exec {
                command = ["/wait-shutdown"]
              }
            }
          }
        }

        # volume {
        #   name = kubernetes_service_account.nginx.default_secret_name

        #   secret {
        #     secret_name = kubernetes_service_account.nginx.default_secret_name
        #   }
        # }
      }
    }
  }
}

resource "kubernetes_limit_range" "nginx" {
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.nginx.metadata.0.name

    labels = {
      "app.kubernetes.io/name"       = var.name
      "app.kubernetes.io/part-of"    = kubernetes_namespace.nginx.metadata.0.name
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    limit {
      type = "Container"
      min = {
        "memory" = "90Mi"
        "cpu"    = "100m"
      }
    }
  }
}

resource "kubernetes_pod_disruption_budget" "nginx" {
  count = var.controller_replicas > 1 ? 1 : 0
  metadata {
    name      = var.name
    namespace = kubernetes_namespace.nginx.metadata.0.name
  }
  spec {
    max_unavailable = var.disruption_budget_max_unavailable
    selector {
      match_labels = {
        "app.kubernetes.io/name" = var.name
      }
    }
  }
}
