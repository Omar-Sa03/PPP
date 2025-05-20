# main.tf

# Configure the Azure provider
provider "azurerm" {
  features {}
}

# Define variables
variable "location" {
  default = "eastus"
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "foodadvisor-rg"
  location = var.location
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "foodadvisor-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a public IP
resource "azurerm_public_ip" "pip" {
  name                = "foodadvisor-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

# Create a network interface
resource "azurerm_network_interface" "nic" {
  name                = "foodadvisor-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# Create a network security group
resource "azurerm_network_security_group" "nsg" {
  name                = "foodadvisor-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# Create an NSG rule to allow SSH
resource "azurerm_network_security_rule" "ssh" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Associate NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a Linux virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "foodadvisor-vm"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s" # Free-tier eligible
  admin_username                  = "azureuser"
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
}

# Install Docker and Docker Compose on the VM
resource "null_resource" "docker_install" {
  depends_on = [azurerm_linux_virtual_machine.vm, azurerm_subnet_network_security_group_association.nsg_association]

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io docker-compose"
    ]
    connection {
      host        = azurerm_public_ip.pip.ip_address
      type        = "ssh"
      user        = "azureuser"
      private_key = file("~/.ssh/id_rsa")
      timeout     = "5m" # Increased timeout to 5 minutes
    }
  }
}