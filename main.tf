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

resource "yandex_vpc_network" "test-2" {
  name = "network"
}

resource "yandex_vpc_subnet" "subnet-test" {
  v4_cidr_blocks = ["192.168.20.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.test-2.id
}



resource "yandex_compute_instance" "test3" {
  count       = 2
  name        = "vm${count.index}"
  platform_id = "standard-v1"
  boot_disk {
    initialize_params {
      image_id = "fd8vbtqkqb6fhhksv1p4"
      type     = "network-hdd"
      size     = 5
    }
  }

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 5
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

resource "yandex_lb_target_group" "tg-test" {
  name = "my-target-group"

  target {
    subnet_id = yandex_vpc_subnet.subnet-test.id
    address   = yandex_compute_instance.test3[0].network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet-test.id
    address   = yandex_compute_instance.test3[1].network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "lb-test" {
  name = "network-lb"

  listener {
    name = "my-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.tg-test.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}