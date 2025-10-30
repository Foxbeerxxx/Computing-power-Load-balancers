resource "yandex_kms_symmetric_key" "bucket_key" {
  name                = "kms-bucket-key"
  description         = "Key for encrypting bucket contents"
  default_algorithm   = "AES_256"
  rotation_period     = "8760h" # 1 год
  deletion_protection = false
}
