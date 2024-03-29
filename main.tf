variable hostname_blocks {}
variable name_blocks {}
variable images_blocks {}
variable cores_blocks {}
variable memory_blocks {}
variable core_fraction_blocks {}
variable count_vm {}


terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  token     = var.token
  cloud_id  = "aje789a9p2bcauis64hl" # Идентификтор в сервисном акк
  folder_id = "b1g5n8seedm7iub1qbob"
  zone      = "ru-central1-a"
}

resource "yandex_vpc_network" "test" {
  name = "network"
}

resource "yandex_vpc_subnet" "subnet-test" {
  v4_cidr_blocks = ["192.168.20.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.test.id
}



resource "yandex_compute_instance" "vm" {
  count       = "${var.count_vm}"
  name        = "${var.count_vm}"
  hostname    = "${var.hostname_blocks[count.index]}"

  allow_stopping_for_update = true
  platform_id = "standard-v1"
  
  resources {
    cores         = "${var.cores_blocks[count.index]}"
    memory        = "${var.memory_blocks[count.index]}"
    core_fraction = "${var.core_fraction_blocks[count.index]}"
  }

  boot_disk {
    initialize_params {
      image_id = "${var.images_blocks[count.index]}"
      size = 16
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-test.id
    nat       = true
  }

  metadata = {
    user-data = file("./meta.yml")
  }

  scheduling_policy {
    preemptible = true
  }
}