provider "libvirt" {
  uri = "qemu:///system"
}

module "cloudinit" {
  source      = "./terraform/libvirt/images/cloudinit"
  unique_name = "archlinux-cloudinit.iso"
}

module "archlinux" {
  source = "./terraform/libvirt/images/archlinux/"
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

resource "libvirt_volume" "archlinux_disk" {
  name           = "archlinux-${count.index}"
  base_volume_id = "${module.archlinux.archlinux_id}"
  pool           = "default"
  count          = "${var.count}"
}

resource "libvirt_domain" "archlinux" {
  name      = "archlinux-${count.index}"
  memory    = "1024"
  vcpu      = 1
  count     = "${var.count}"
  cloudinit = "${module.cloudinit.cloudinit_id}"

  network_interface {
    network_name = "default"
  }

  // OS image
  disk {
    volume_id = "${element(libvirt_volume.archlinux_disk.*.id, count.index)}"
  }

  // DISK
  disk {
    volume_id = "${element(libvirt_volume.osd_disks.*.id, count.index)}"
  }

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
