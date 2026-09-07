provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

data "http" "public_ip_addr" {
  count =  var.my_ip == "" ? 1 : 0
  url = "https://ipinfo.io/ip"
}


resource "azurerm_resource_group" "neptune_rg" {
  name = "neptune-rg"
  location = var.location
}

resource "azurerm_network_watcher" "neptune_nwwatcher" {
  name                = "neptune-nwwatcher"
  location            = azurerm_resource_group.neptune_rg.location
  resource_group_name = azurerm_resource_group.neptune_rg.name
}

resource "azurerm_virtual_network" "neptune_vn" {
  name = "neptune-vn"
  resource_group_name = azurerm_resource_group.neptune_rg.name
  location = azurerm_resource_group.neptune_rg.location
  address_space = [var.vn_cidr_block]
}

module "artifactory_vm" {
  source = "./modules/linux-VM"
  application_name = "artifactory"
  application_subnet_cidr_block = var.artifactory_subnet_cidr_block
  linux_admin = var.linux_admin
  rg_name = azurerm_resource_group.neptune_rg.name
  my_ip = var.my_ip
  vn_name = azurerm_virtual_network.neptune_vn.name
  vn_location = azurerm_virtual_network.neptune_vn.location
}


module "artifactory_db" {
  count = var.op_mode == "enterprise" ? 1 : 0
  source = "./modules/postgres-DB"
  vn_id = azurerm_virtual_network.neptune_vn.id
  vn_name = azurerm_virtual_network.neptune_vn.name
  vn_location = azurerm_virtual_network.neptune_vn.location
  db_subnet_cidr_block = var.artifactory_db_subnet_cidr_block
  rg_name = azurerm_resource_group.neptune_rg.name
  psql_admin = var.psql_admin
  psql_password = var.psql_password
  db_name = "artifactory_db"
  application_private_ip = module.artifactory_vm.application_private_ip_address
  application_name = "artifactory"
}

module "artifactory_db_vm" {
  count = var.op_mode == "budget" ? 1 : 0
  source = "./modules/postgres-VM"
  application_ip = module.artifactory_vm.application_private_ip_address
  application_name = "artifactoryDB"
  application_subnet_cidr_block = var.artifactory_db_subnet_cidr_block
  db_name = "artifactory_db"
  my_ip = var.my_ip
  linux_admin = var.linux_admin
  rg_name = azurerm_resource_group.neptune_rg.name
  vn_location = azurerm_virtual_network.neptune_vn.location
  vn_name = azurerm_virtual_network.neptune_vn.name
  psql_admin = var.psql_admin
  psql_password = var.psql_password
  depends_on = [ module.artifactory_vm ]
}

# module "gitea-vm" {
#   source = "./modules/linux-VM"
#   application_name = "gitea"
#   application_subnet_cidr_block = var.gitea_subnet_cidr_block
#   linux_admin = var.linux_admin
#   rg_name = azurerm_resource_group.neptune_rg.name
#   my_ip = var.my_ip
#   vn_name = azurerm_virtual_network.neptune_vn.name
#   vn_location = azurerm_virtual_network.neptune_vn.location
# }

# module "gitea_db" {
#   source = "./modules/postgres-DB"
#   vn_id = azurerm_virtual_network.neptune_vn.id
#   vn_name = azurerm_virtual_network.neptune_vn.name
#   vn_location = azurerm_virtual_network.neptune_vn.location
#   db_subnet_cidr_block = var.gitea_db_subnet_cidr_block
#   rg_name = azurerm_resource_group.neptune_rg.name
#   psql_admin = var.psql_admin
#   psql_password = var.psql_password
#   application_private_ip = module.gitea-vm.application_private_ip_address
#   application_name = "gitea"
# }

# resource "azurerm_postgresql_flexible_server_configuration" "gitea_db_password_encryption_parameter" {
#   server_id = module.gitea_db.postgres-db-server_id
#   name = "password_encryption"
#   value = "scram-sha-256"
# }

resource "null_resource" "artifactory_setup" {
  count = var.op_mode == "budget" ? 1 : 0
  provisioner "local-exec" {
    command = "echo DB_ENDPOINT: ${module.artifactory_db_vm[0].db-vm-private_ip} >> ${var.project_path}/ansible/db_vars.yaml"
  }
  depends_on = [module.artifactory_db, module.artifactory_db_vm[0]]
}

resource "null_resource" "artifactory_db_setup" {
  count = var.op_mode == "budget" ? 1 : 0
  provisioner "local-exec" {
    command = "echo APP_IP: ${module.artifactory_vm.application_private_ip_address}/32 >> ${var.project_path}/ansible/db_vars.yaml"
  }
  depends_on = [module.artifactory_db, module.artifactory_db_vm[0]]
}

resource "null_resource" "artifactory_db_runner" {
  count = var.op_mode == "budget" ? 1 : 0
  depends_on = [module.artifactory_db_vm, null_resource.artifactory_db_setup]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/hosts ${var.project_path}/ansible/artifactory-db-playbook.yaml"
  }
}

resource "null_resource" "artifactory_azure_db_setup" {
  count = var.op_mode == "enterprise" ? 1 : 0
  depends_on = [module.artifactory_db]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/hosts ${var.project_path}/ansible/artifactory-azure-db-playbook.yaml"
  }
}

resource "null_resource" "artifactory_playbook_runner" {
  depends_on = [ module.artifactory_db, module.artifactory_db_vm, module.artifactory_vm, null_resource.artifactory_db_runner, null_resource.artifactory_setup, null_resource.artifactory_azure_db_setup]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/hosts ${var.project_path}/ansible/artifactory-playbook.yaml"
  }
}