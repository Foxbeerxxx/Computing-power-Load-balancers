# Домашнее задание к занятию "`Вычислительные мощности. Балансировщики нагрузки`" - `Татаринцев Алексей`


---

### Задание 2 Вычислительные мощности. Балансировщики нагрузки


1. `Создам сервисный аккаутн для задания в YC`
```
# сервисный аккаунт под Storage
yc iam service-account create --name tf-storage
SA_ID=$(yc iam service-account get --name tf-storage --format json | jq -r .id)

# вывод
done (1s)
id: aje8090r68h9tudimo46
folder_id: b1gse67sen06i8u6ri78
created_at: "2025-10-27T18:22:52.913867494Z"
name: tf-storage

There is a new yc version '0.172.0' available. Current version: '0.171.0'.
See release notes at https://yandex.cloud/ru/docs/cli/release-notes
You can install it by running the following command in your shell:
        $ yc components update

# права на каталог
yc resource-manager folder add-access-binding \
  --id b1gse67sen06i8u6ri78 \
  --role storage.admin \
  --service-account-id "$SA_ID"

  

# вывод
done (2s)
effective_deltas:
  - action: ADD
    access_binding:
      role_id: storage.admin
      subject:
        id: aje8090r68h9tudimo46
        type: serviceAccount

# статический ключ
yc iam access-key create --service-account-id "$SA_ID"

# Экспортирую в окружение, чтобы не светить в GitHub

export YC_STORAGE_ACCESS_KEY="<access_key_id>"
export YC_STORAGE_SECRET_KEY="<secret>"

```

2. `provider.tf`
```
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.98"
    }
  }
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = "b1gvjpk4qbrvling8qq1"
  folder_id                = "b1gse67sen06i8u6ri78"
  zone                     = "ru-central1-a"

  storage_access_key = var.storage_access_key
  storage_secret_key = var.storage_secret_key
}

variable "storage_access_key" {
  type      = string
  sensitive = true
}

variable "storage_secret_key" {
  type      = string
  sensitive = true
}
```

3. `bucket.tf — бакет и картинка`

```
locals {
  bucket_name = "alexey-${formatdate("YYYYMMDD", timestamp())}"
}

resource "yandex_storage_bucket" "img" {
  bucket = local.bucket_name
  acl    = "public-read"

  anonymous_access_flags {
    read = true
    list = true
  }

  force_destroy = true
}

resource "yandex_storage_object" "pic" {
  bucket = yandex_storage_bucket.img.bucket
  key    = "pic.jpg"
  source = "${path.module}/files/pic.jpg"
  acl    = "public-read"
}

output "public_image_url" {
  value = "https://storage.yandexcloud.net/${yandex_storage_bucket.img.bucket}/${yandex_storage_object.pic.key}"
}

```

4. `ig.tf — Instance Group из трёх LAMP-ВМ`

```
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

```

5. `nlb.tf — сетевой балансировщик с health-check`

```
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

```

6. `Запускаем`

```
terraform init
terraform apply

```
![1](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img1.png)

![2](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img2.png)

![3](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img3.png)

![4](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img4.png)

6. `Из вывода `
```
nlb_public_ip = "84.201.149.149" — IP-адрес сетевого балансировщика.

https://storage.yandexcloud.net/alexey-20251027/pic.jpg  — публичная ссылка на картинку из Object Storage.  

```
6. `Работа с балансировщиком`

```
Открываю сайт на балансировщике:
http://84.201.149.149/

```
![5](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img5.png)

6. `Затем удаляю 1 ВМ и перезагружаю сайт на балансировщике- всё работает`

![5](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img5.png)

6. ` Удаляю всю  дз  - terraform destroy`

```
Обновляю
http://84.201.149.149/
и вижу при обновлении на какие хосты он обращался.
```
![6](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img6.png)

![7](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img7.png)



### Задание 3 Безопасность в облачных провайдерах

1. `Использую предыдущее задание, допиливаю на текущее дз`
2. `Дописываю шифрование в bucket.tf`

```
locals {
  bucket_name = "alexey-${formatdate("YYYYMMDD", timestamp())}"
}

resource "yandex_storage_bucket" "img" {
  bucket = local.bucket_name
  acl    = "public-read"

  anonymous_access_flags {
    read = true
    list = true
  }

  force_destroy = true

  # 🔐 Добавляем шифрование через KMS
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.bucket_key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "yandex_storage_object" "pic" {
  bucket = yandex_storage_bucket.img.bucket
  key    = "pic.jpg"
  source = "${path.module}/files/pic.jpg"
  acl    = "public-read"
}

output "public_image_url" {
  value = "https://storage.yandexcloud.net/${yandex_storage_bucket.img.bucket}/${yandex_storage_object.pic.key}"
}


```

3. `kms.tf`

```
resource "yandex_kms_symmetric_key" "bucket_key" {
  name                = "kms-bucket-key"
  description         = "Key for encrypting bucket contents"
  default_algorithm   = "AES_256"
  rotation_period     = "8760h" # 1 год
  deletion_protection = false
}

```

4. `Поднимаю структуру `

```
terraform fmt
terraform validate
terraform init -upgrade
terraform apply
```
![8](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img8.png)

![9](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img9.png)

![10](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img10.png)


5. `Захожу в бакет и проверяю Шифрование на картинки`
![11](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img11.png)

![12](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img12.png)

![13](https://github.com/Foxbeerxxx/Computing-power-Load-balancers/blob/main/img/img13.png)

5. `Ну и terraform destroy`