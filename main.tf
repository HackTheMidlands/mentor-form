provider "google" {
  credentials = "${file("deploy/credentials/gcloud.json")}"
  project     = "${jsondecode(file("credentials/gcloud.json"))["project_id"]}"
  region      = "europe-west2"
  zone        = "europe-west2-a"
}

resource "random_id" "helpq" {
  byte_length = 8
}

resource "tls_private_key" "connection_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_address" "helpq" {
  name = "helpq-address"
}

resource "google_compute_network" "helpq_network" {
  name = "helpq-network"
}

resource "google_compute_firewall" "helpq_firewall" {
  name    = "helpq-firewall"
  network = "${google_compute_network.helpq_network.name}"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }
}

resource "google_compute_instance" "helpq" {
  name         = "helpq-${random_id.helpq.hex}"
  machine_type = "n1-standard-2"

  boot_disk {
    initialize_params {
      image = "gce-uefi-images/ubuntu-1804-lts"
    }
  }

  scratch_disk {
  }

  provisioner "file" {
    source      = "private/config.json"
    destination = "/root/config.json"

    connection {
      type = "ssh"
      user = "root"
      host = "${google_compute_address.helpq.address}"
      private_key = "${tls_private_key.connection_key.private_key_pem}"
    }
  }

  provisioner "file" {
    source      = "deploy/helpq.nginx"
    destination = "/root/helpq.nginx"

    connection {
      type = "ssh"
      user = "root"
      host = "${google_compute_address.helpq.address}"
      private_key = "${tls_private_key.connection_key.private_key_pem}"
    }
  }

  metadata_startup_script = "${file("./deploy/setup.sh")}"

  network_interface {
    network = "${google_compute_network.helpq_network.name}"
    access_config {
      nat_ip = "${google_compute_address.helpq.address}"
    }
  }

  metadata = {
    ssh-keys = "root:${tls_private_key.connection_key.public_key_openssh}"
  }
}

output "helpq-ip" {
  value = "${google_compute_address.helpq.address}"
}
