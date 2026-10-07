variable "azure_subscription_id" {}

variable "location" {
  default = "East US 2"
}

variable "vn_cidr_block" {
  default = "10.0.0.0/16"
}

variable "artifactory_subnet_cidr_block" {
  default = "10.0.1.0/24"
}

variable "artifactory_db_subnet_cidr_block" {
  default = "10.0.2.0/24"
}

variable "artifactory_db_name" {
  default = "artifactory_db"
}

variable "gitea_subnet_cidr_block" {
  default = "10.0.3.0/24"
}

variable "gitea_db_subnet_cidr_block" {
  default = "10.0.4.0/24"
}

variable "gitea_db_name" {
  default = "giteadb"
}

variable "jenkins_subnet_cidr_block" {
  default = "10.0.5.0/24"
}

variable "prometheus_subnet_cidr_block" {
  default = "10.0.6.0/24"
}

variable "linux_admin" {
  default = "neptune-admin"
  sensitive = true
}

variable "psql_admin" {
  default = "neptune"
}

variable "psql_password" {}


variable "project_path" {
  default = "~/Desktop/neptune"
}

variable "my_ip" {
  default = ""
}

variable "op_mode" {
  default = "regular"
}

variable "artifactory_vm_application_name" {
  default = "artifactory"
}

variable "artifactory_db_application_name" {
  default = "artifactorydb"
}

variable "gitea_vm_application_name" {
  default = "gitea"
}

variable "gitea_db_application_name" {
  default = "giteadb"
}

variable "ssh_pub_key_absolute_path" {}