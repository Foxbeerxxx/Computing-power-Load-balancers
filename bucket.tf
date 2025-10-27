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
