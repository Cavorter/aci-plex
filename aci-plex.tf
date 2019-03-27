variable "name" {
  type = "string"
}

variable "location" {
  type = "string"
  default = "centralus"
}

provider "azurerm" {
  version = "=1.23.0"
}

resource "azurerm_resource_group" "plex-rg" {
  name     = "${var.name}-plex"
  location = "${var.location}"
}

resource "azurerm_storage_account" "plex-sa" {
  name                = "${var.name}plex"
  resource_group_name = "${azurerm_resource_group.plex-rg.name}"
  location            = "${azurerm_resource_group.plex-rg.location}"
  account_tier        = "Standard"
  account_kind        = "StorageV2"

  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "plex-share-config" {
  name = "plexconfig"

  resource_group_name  = "${azurerm_resource_group.plex-rg.name}"
  storage_account_name = "${azurerm_storage_account.plex-sa.name}"
}

resource "azurerm_storage_share" "plex-share-media" {
  name = "plexmedia"

  resource_group_name  = "${azurerm_resource_group.plex-rg.name}"
  storage_account_name = "${azurerm_storage_account.plex-sa.name}"
}

resource "azurerm_container_group" "plex-container" {
  name                = "${var.name}-plex-media-server"
  location            = "${azurerm_resource_group.plex-rg.location}"
  resource_group_name = "${azurerm_resource_group.plex-rg.name}"
  ip_address_type     = "public"
  dns_label_name      = "${var.name}-plex"
  os_type             = "Linux"

  container {
    name   = "pms"
    image  = "plexinc/pms-docker"
    cpu    = "2.0"
    memory = "1.0"

    ports = {
      port     = 32400
      protocol = "TCP"
    }

    environment_variables = {
      "TZ" = "America/Chicago"
      "PLEX_CLAIM" = "claim-VojpdTyyHWggUZLpsWR3"
    }

    volume {
      name       = "config"
      mount_path = "/config"
      read_only  = false
      share_name = "${azurerm_storage_share.plex-share-config.name}"

      storage_account_name = "${azurerm_storage_account.plex-sa.name}"
      storage_account_key  = "${azurerm_storage_account.plex-sa.primary_access_key}"
    }
    
    volume {
      name       = "media"
      mount_path = "/data"
      read_only  = false
      share_name = "${azurerm_storage_share.plex-share-media.name}"

      storage_account_name = "${azurerm_storage_account.plex-sa.name}"
      storage_account_key  = "${azurerm_storage_account.plex-sa.primary_access_key}"
    }
  }

  tags = {
      application = "plex"
  }
}
