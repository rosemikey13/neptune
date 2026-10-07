provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}


resource "azurerm_resource_group" "neptune_rg" {
  name = "neptune-rg"
  location = var.location
}

resource "null_resource" "starting-message" {
  provisioner "local-exec" {
    command = "echo 'Starting Neptune in ${var.op_mode} mode.' "
  }
}

resource "azurerm_virtual_network" "neptune_vn" {
  name = "neptune-vn"
  resource_group_name = azurerm_resource_group.neptune_rg.name
  location = azurerm_resource_group.neptune_rg.location
  address_space = [var.vn_cidr_block]
}


module "artifactory_vm" {
  source = "./modules/linux-VM"
  application_name = var.artifactory_vm_application_name
  application_subnet_cidr_block = var.artifactory_subnet_cidr_block
  linux_admin = var.linux_admin
  rg_name = azurerm_resource_group.neptune_rg.name
  my_ip = var.my_ip
  vn_name = azurerm_virtual_network.neptune_vn.name
  vn_location = azurerm_virtual_network.neptune_vn.location
  ssh_pub_key_absolute_path = var.ssh_pub_key_absolute_path
  spot_instance = var.op_mode == "development" ? true : false
  monitoring_ip = module.prometheus_vm.application_public_ip_address
  depends_on = [ module.prometheus_vm ]
}

module "artifactory_db" {
  source = "./modules/postgres-db"
  monitoring_ip = module.prometheus_vm.application_public_ip_address
  op_mode = var.op_mode
  application_name = var.artifactory_db_application_name
  application_private_ip = module.artifactory_vm.application_private_ip_address
  db_subnet_cidr_block = var.artifactory_db_subnet_cidr_block
  db_name = var.artifactory_db_name
  my_ip = var.my_ip
  linux_admin = var.linux_admin
  psql_admin = var.psql_admin
  psql_password = var.psql_password
  ssh_pub_key_absolute_path = var.ssh_pub_key_absolute_path
  rg_name = azurerm_resource_group.neptune_rg.name
  vn_id = azurerm_virtual_network.neptune_vn.id
  vn_location = azurerm_virtual_network.neptune_vn.location
  vn_name = azurerm_virtual_network.neptune_vn.name
  depends_on = [ module.prometheus_vm ]
}

module "gitea_vm" {
  source = "./modules/linux-VM"
  monitoring_ip = module.prometheus_vm.application_public_ip_address
  application_name = var.gitea_vm_application_name
  application_subnet_cidr_block = var.gitea_subnet_cidr_block
  linux_admin = var.linux_admin
  rg_name = azurerm_resource_group.neptune_rg.name
  my_ip = var.my_ip
  vn_name = azurerm_virtual_network.neptune_vn.name
  vn_location = azurerm_virtual_network.neptune_vn.location
  vm_size = "Standard_D2alds_v7"
  ssh_pub_key_absolute_path = var.ssh_pub_key_absolute_path
  depends_on = [ module.artifactory_vm, module.prometheus_vm ]
}

module "gitea_db" {
  source = "./modules/postgres-db"
  monitoring_ip = module.prometheus_vm.application_public_ip_address
  op_mode = var.op_mode
  application_name = var.gitea_db_application_name
  application_private_ip = module.gitea_vm.application_private_ip_address
  db_subnet_cidr_block = var.gitea_db_subnet_cidr_block
  db_name = var.gitea_db_name
  my_ip = var.my_ip
  linux_admin = var.linux_admin
  psql_admin = var.psql_admin
  psql_password = var.psql_password
  ssh_pub_key_absolute_path = var.ssh_pub_key_absolute_path
  rg_name = azurerm_resource_group.neptune_rg.name
  vn_id = azurerm_virtual_network.neptune_vn.id
  vn_location = azurerm_virtual_network.neptune_vn.location
  vn_name = azurerm_virtual_network.neptune_vn.name
  depends_on = [ module.prometheus_vm ]
}

resource "azurerm_postgresql_flexible_server_configuration" "gitea_azure_db_config_1" {
  count = var.op_mode == "enterprise" ? 1 : 0
  name = "password_encryption"
  value = "scram-sha-256"
  server_id = module.gitea_db.postgres-flexible-server-id
}

module "jenkins_vm" {
  source = "./modules/linux-VM"
  monitoring_ip = module.prometheus_vm.application_public_ip_address
  application_name = "jenkins"
  application_subnet_cidr_block = var.jenkins_subnet_cidr_block
  linux_admin = var.linux_admin
  rg_name = azurerm_resource_group.neptune_rg.name
  my_ip = var.my_ip
  vn_name = azurerm_virtual_network.neptune_vn.name
  vn_location = azurerm_virtual_network.neptune_vn.location
  vm_size = "Standard_D2alds_v7"
  ssh_pub_key_absolute_path = var.ssh_pub_key_absolute_path
}


resource "null_resource" "jenkins_setup" {
  provisioner "local-exec" {
    command = "echo VM_ENDPOINT: ${module.jenkins_vm.application_public_ip_address} > ${var.project_path}/ansible/jenkins/vars/app_vars.yaml"
  }
  depends_on = [module.jenkins_vm]
}

resource "null_resource" "jenkins_playbook_runner" {
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/jenkins/hosts ${var.project_path}/ansible/jenkins/jenkins-playbook.yaml"
  }
  depends_on = [ module.jenkins_vm, null_resource.jenkins_setup, null_resource.artifactory_db_runner, null_resource.gitea_db_runner, null_resource.gitea_playbook_runner, null_resource.artifactory_playbook_runner]
}

module "prometheus_vm" {
  source = "./modules/linux-VM"
  monitoring_ip = module.prometheus_vm.application_public_ip_address
  application_name = "prometheus"
  application_subnet_cidr_block = var.prometheus_subnet_cidr_block
  linux_admin = var.linux_admin
  rg_name = azurerm_resource_group.neptune_rg.name
  my_ip = var.my_ip
  vn_name = azurerm_virtual_network.neptune_vn.name
  vn_location = azurerm_virtual_network.neptune_vn.location
  vm_size = "Standard_D2alds_v7"
  ssh_pub_key_absolute_path = var.ssh_pub_key_absolute_path  
}

resource "null_resource" "prometheus_setup" {
  provisioner "local-exec" {
    command = "echo VM_ENDPOINT: ${module.jenkins_vm.application_public_ip_address} > ${var.project_path}/ansible/prometheus/vars/app_vars.yaml"
  }
  depends_on = [module.prometheus_vm]
}

resource "null_resource" "prometheus_playbook_runner" {
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/prometheus/hosts ${var.project_path}/ansible/prometheus/prometheus-playbook.yaml"
  }
  depends_on = [ null_resource.prometheus_setup, null_resource.jenkins_playbook_runner ]
}


resource "null_resource" "artifactory_setup" {
  provisioner "local-exec" {
    command = "echo DB_ENDPOINT: ${module.artifactory_db.db-private-ip} > ${var.project_path}/ansible/${var.artifactory_vm_application_name}/db_vars.yaml"
  }
  provisioner "local-exec" {
     command = "echo DB_USER: ${var.psql_admin} >> ${var.project_path}/ansible/${var.artifactory_vm_application_name}/db_vars.yaml"
  }
  provisioner "local-exec" {
     command = "echo DB_PASSWORD: ${var.psql_password} >> ${var.project_path}/ansible/${var.artifactory_vm_application_name}/db_vars.yaml"
  }
    provisioner "local-exec" {
     command = "echo DB_NAME: ${var.artifactory_db_name} >> ${var.project_path}/ansible/${var.artifactory_vm_application_name}/db_vars.yaml"
  }
  depends_on = [module.artifactory_db[0]]
}

resource "null_resource" "artifactory_db_setup" {
  count = var.op_mode == "development" ? 1 : var.op_mode == "regular" ? 1 : 0
  provisioner "local-exec" {
    command = "echo APP_IP: ${module.artifactory_vm.application_private_ip_address}/32 >> ${var.project_path}/ansible/${var.artifactory_db_application_name}/db_vars.yaml"
  }
  depends_on = [module.artifactory_db[0]]
}


resource "null_resource" "artifactory_azure_db_setup" {
  count = var.op_mode == "enterprise" ? 1 : 0
  depends_on = [module.artifactory_db]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/${var.artifactory_db_application_name}/hosts ${var.project_path}/ansible/${var.artifactory_db_application_name}/artifactory-azure-db-playbook.yaml"
  }
}

resource "null_resource" "gitea_setup" {
  provisioner "local-exec" {
    command = "echo DB_ENDPOINT: ${module.gitea_db.db-private-ip} > ${var.project_path}/ansible/${var.gitea_vm_application_name}/db_vars.yaml"
  }
  provisioner "local-exec" {
     command = "echo DB_USER: ${var.psql_admin} >> ${var.project_path}/ansible/${var.gitea_vm_application_name}/db_vars.yaml"
  }
  provisioner "local-exec" {
     command = "echo DB_PASSWORD: ${var.psql_password} >> ${var.project_path}/ansible/${var.gitea_vm_application_name}/db_vars.yaml"
  }
  provisioner "local-exec" {
     command = "echo DB_NAME: ${var.gitea_db_name} >> ${var.project_path}/ansible/${var.gitea_vm_application_name}/db_vars.yaml"
  }
  depends_on = [ module.gitea_db[0]]
}

resource "null_resource" "gitea_db_setup" {
  count = var.op_mode == "development" ? 1 : var.op_mode == "regular" ? 1 : 0
  provisioner "local-exec" {
    command = "echo APP_IP: ${module.gitea_vm.application_private_ip_address}/32 >> ${var.project_path}/ansible/${var.gitea_db_application_name}/db_vars.yaml"
  }
  depends_on = [module.gitea_db[0]]
}

resource "null_resource" "artifactory_db_runner" {
  count = var.op_mode == "development" ? 1 : var.op_mode == "regular" ? 1 : 0
  depends_on = [module.artifactory_db, null_resource.artifactory_db_setup]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/${var.artifactory_db_application_name}/hosts ${var.project_path}/ansible/${var.artifactory_db_application_name}/artifactory-db-playbook.yaml"
  }
}

resource "null_resource" "artifactory_playbook_runner" {
  depends_on = [ module.artifactory_db, module.artifactory_db, module.artifactory_vm, null_resource.artifactory_db_runner, null_resource.artifactory_setup, null_resource.artifactory_azure_db_setup]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/${var.artifactory_vm_application_name}/hosts ${var.project_path}/ansible/${var.artifactory_vm_application_name}/artifactory-playbook.yaml"
  }
}


resource "null_resource" "gitea_db_runner" {
  count = var.op_mode == "development" ? 1 : var.op_mode == "regular" ? 1 : 0
  depends_on = [module.gitea_db[0], null_resource.gitea_db_setup]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/${var.gitea_db_application_name}/hosts ${var.project_path}/ansible/${var.gitea_db_application_name}/gitea-db-playbook.yaml"
  }
}

resource "null_resource" "gitea_azure_db_setup" {
  count = var.op_mode == "enterprise" ? 1 : 0
  depends_on = [module.gitea_db]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/${var.gitea_db_application_name}/hosts ${var.project_path}/ansible/${var.gitea_db_application_name}/gitea-azure-db-playbook.yaml"
  }
}

resource "null_resource" "gitea_playbook_runner" {
  depends_on = [ module.gitea_db, module.gitea_vm, null_resource.gitea_db_runner, null_resource.gitea_setup]
  provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/${var.gitea_vm_application_name}/hosts ${var.project_path}/ansible/${var.gitea_vm_application_name}/gitea-playbook.yaml"
  }
} 