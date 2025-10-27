resource "yandex_lb_network_load_balancer" "nlb" {
  name = "lamp-nlb"

  listener {
    name = "http-80"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.lamp_ig.load_balancer[0].target_group_id

    healthcheck {
      name = "hc-http"
      http_options {
        port = 80
        path = "/"
      }
      interval            = 5
      timeout             = 2
      unhealthy_threshold = 2
      healthy_threshold   = 2
    }
  }
}

output "nlb_public_ip" {
  value = flatten([
    for l in yandex_lb_network_load_balancer.nlb.listener : [
      for a in l.external_address_spec : a.address
    ]
  ])[0]
}



