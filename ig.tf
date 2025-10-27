# шаблон пользовательских данных: простая страница с ссылкой на картинку из бакета
locals {
  index_html = <<-EOF
    <html>
      <head><title>Netology LAMP</title></head>
      <body>
        <h1>Instance Group LAMP</h1>
        <p>Картинка из Object Storage:</p>
        <img src="https://storage.yandexcloud.net/${yandex_storage_bucket.img.bucket}/${yandex_storage_object.pic.key}" style="max-width:600px;">
      </body>
    </html>
  EOF

  user_data = <<-EOF
    #!/bin/bash
    cat > /var/www/html/index.html <<'EOPAGE'
    ${replace(local.index_html, "$", "\\$")}
    EOPAGE
    systemctl restart apache2 || systemctl restart httpd || true
  EOF
}

resource "yandex_compute_instance_group" "lamp_ig" {
  name               = "lamp-ig"
  service_account_id = "aje8090r68h9tudimo46"

  instance_template {
    platform_id = "standard-v1"

    resources {
      cores  = 2
      memory = 2
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd827b91d99psvq5fjit"
        size     = 10
        type     = "network-hdd"
      }
    }

    network_interface {
      subnet_ids = [yandex_vpc_subnet.public.id] # из твоей public подсети
      nat        = true
    }

    metadata = {
      user-data = local.user_data
      ssh-keys  = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 1
    max_creating    = 1
    max_expansion   = 1
    max_deleting    = 1
    strategy        = "proactive"
  }

  # создаём target group автоматически для NLB
  load_balancer {
    target_group_name = "lamp-ig-tg"
  }
}
