# terraform-kubernetes-nginx-ingress-controller

This fork improve https://github.com/byuoitav/terraform-kubernetes-nginx-ingress-controller by adding greater control to nginx ingress controller, enabling allowing extra TCP and UDP services to be added to Load balancer port.

In AWS, this will trigger kubernetes ingress to create target groups required to not only provide ingress for port 80 and 443, also allow additional ports.

### Sample usage

```
module nginx-ingress-controller {
  source  = "github.com/sanarena/terraform-kubernetes-nginx-ingress-controller"
  # however recommended way is to add this repository as a submodule

  # optional
  nginx_ingress_controller_version = "0.33.0"
  name = "ingress-nginx"
  nginx_config {
    "ssl-protocols"     = "TLSv1.2" # Only Support TLSv1.2
	"proxy-buffer-size" = "16k"
  }
  load_balancer_source_ranges = ["1.2.3.4/32"]
  tcp_services = {
    "panel" = {
      namespace="default"
      service_name="controlpanel"
      container_port="80"
      ingress_port="8081"
    },
    "mysql" = {
      namespace="default"
      service_name="mysql"
      container_port="3306"
      ingress_port="3306"
    }
  }
  udp_services = {
    "openvpn" = {
      namespace="default"
      service_name="openvpn"
      container_port="1194"
      ingress_port="1194"
    }
  }
  lb_annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout": 360
    "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags": "environment=test,name=kubernetes-ingress"
  }
}
```
