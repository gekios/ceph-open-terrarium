provider "libvirt" {
  uri = "qemu:///system"
}

module "cloudinit" {
  source      = "./terraform/libvirt/images/cloudinit"
  unique_name = "ubuntu_cloudinit.iso"
}

module "ubuntu" {
  source = "./terraform/libvirt/images/ubuntu/"
}

// Create 4 instances
variable "count" {
  default = 4
}

resource "libvirt_volume" "osd_disks" {
  pool   = "default"
  format = "raw"
  name   = "osd_${count.index}_data.raw"
  count  = "${var.count}"
}

resource "libvirt_volume" "ubuntu_disk" {
  name           = "ubuntu1804-${count.index}"
  base_volume_id = "${module.ubuntu.ubuntu_1804_id}"
  pool           = "default"
  count          = "${var.count}"
}

resource "libvirt_domain" "ubuntu1804" {
  name      = "ubuntu1804-${count.index}"
  memory    = "1024"
  vcpu      = 1
  count     = "${var.count}"
  cloudinit = "${module.cloudinit.cloudinit_id}"

  network_interface {
    network_name = "default"
  }

  // OS image
  disk {
    volume_id = "${element(libvirt_volume.ubuntu_disk.*.id, count.index)}"
  }

  // DISK
  disk {
    volume_id = "${element(libvirt_volume.osd_disks.*.id, count.index)}"
  }

  # IMPORTANT
  # Ubuntu can hang if an isa-serial is not present at boot time.
  # If you find your CPU 100% and never is available this is why
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}
