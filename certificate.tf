resource "yandex_cm_certificate" "bucket_cert" {
  name    = "bucket-cert"
  domains = ["alexey-20251027.website.yandexcloud.net"]

  managed {
    challenge_type = "DNS_CNAME"
  }
}

output "certificate_id" {
  value = yandex_cm_certificate.bucket_cert.id
}
