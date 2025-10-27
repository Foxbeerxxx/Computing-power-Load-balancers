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
