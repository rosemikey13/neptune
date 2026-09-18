variable "application_subnet_cidr_block" {}
variable "vn_name" {}
variable "vn_location" {}
variable "application_name" {}
variable "rg_name" {}
variable "my_ip" {}
variable "linux_admin" {}
variable "vm_size" {
default = "Standard_D4alds_v7"
}
variable "ssh_pub_key_absolute_path" {}