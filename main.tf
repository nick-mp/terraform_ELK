variable "hostname_blocks" {}
variable "name_blocks" {}
variable "images_blocks" {}
variable "cores_blocks" {}
variable "memory_blocks" {}
variable "core_fraction_blocks" {}
variable "count_vm" {}


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
  count    = var.count_vm
  name     = var.name_blocks[count.index]
  hostname = var.hostname_blocks[count.index]

  allow_stopping_for_update = true
  platform_id               = "standard-v1"

  resources {
    cores         = var.cores_blocks[count.index]
    memory        = var.memory_blocks[count.index]
    core_fraction = var.core_fraction_blocks[count.index]
  }

  boot_disk {
    initialize_params {
      image_id = var.images_blocks[count.index]
      size     = 16
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


  # создание папок на vm

  provisioner "remote-exec" {
    inline = [
      "cd ~",
      "mkdir -pv configs",
      "mkdir -pv docker_volumes",
      "mkdir -pv docker_volumes/elasticsearch",
      "mkdir -pv configs/elasticsearch",
      "mkdir -pv configs/filebeat",
      "mkdir -pv configs/kibana",
      "mkdir -pv configs/logstash",
      "mkdir -pv configs/logstash/pipelines"
    ]
  }

  # пробрасываем конфиги
  provisioner "file" {
    source      = "./docker/docker-compose.yaml"
    destination = "/home/kim/docker-compose.yaml"
  }

  provisioner "file" {
    source      = "./configs/elasticsearch/config.yaml"
    destination = "/home/kim/configs/elasticsearch/config.yaml"
  }

  provisioner "file" {
    source      = "./configs/filebeat/config.yaml"
    destination = "/home/kim/configs/filebeat/config.yaml"
  }

  provisioner "file" {
    source      = "./configs/kibana/config.yaml"
    destination = "/home/kim/configs/kibana/config.yaml"
  }

  provisioner "file" {
    source      = "./configs/logstash/config.yaml"
    destination = "/home/kim/configs/logstash/config.yaml"
  }

  provisioner "file" {
    source      = "./configs/logstash/pipelines/service_stamped_json_logs.conf"
    destination = "/home/kim/configs/logstash/pipelines/service_stamped_json_logs.conf"
  }

  provisioner "file" {
    source      = "./configs/logstash/pipelines/pipelines.yaml"
    destination = "/home/kim/configs/logstash/pipelines/pipelines.yaml"
  }

  # установка doker, nginx, redis
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y ca-certificates curl",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      "echo \"deb [arch=$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(./etc/os-release && echo '$VERSION_CODENAME') stable | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo groupadd docker",
      "sudo usermod -aG docker $USER",
      "sudo chmod +x /home/kim/docker-compose.yaml",
      "sudo apt-get update",
      "sudo apt install -y nginx",
      "sudo chmod 777 /var/log/nginx/access.log",
      "sudo apt install -y redis",
      "sudo curl localhost",
      "sudo systemctl restart redis",
      "sudo chmod o+rx -R /var/log/redis",
      "sudo docker compose up -d"
    ]
  }


  connection {
    type        = "ssh"
    user        = "kim"
    private_key = file("./.ssh/id_ttr_2903")
    host        = self.network_interface[0].nat_ip_address
  }

}