locals {
  safe-domain-name = replace(var.domain-name, ".", "-")
  mime_types = {
    "css"  = "text/css"
    "html" = "text/html"
    "ico"  = "image/vnd.microsoft.icon"
    "js"   = "application/javascript"
    "json" = "application/json"
    "map"  = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "svg"  = "image/svg+xml"
    "txt"  = "text/plain"
  }
}

resource "namecheap_domain_records" "static-site-dns" {
  domain = var.domain-name
  mode   = "OVERWRITE"

  record {
    hostname = "www"
    type     = "CNAME"
    address  = "${azurerm_cdn_endpoint.static-site-cdn-endpoint.name}.azureedge.net"
    ttl      = 60
  }

  # record {
  #   hostname = "@"
  #   type = "URL301"
  #   address = "https://www.weirdalyzer.com"
  #   ttl = 60
  # }

  record {
    hostname = "@"
    type     = "ALIAS"
    address  = "${azurerm_cdn_endpoint.static-site-cdn-endpoint.name}.azureedge.net"
    ttl      = 60
  }

  record {
    hostname = "asverify"
    type     = "CNAME"
    address  = "asverify.${azurerm_cdn_endpoint.static-site-cdn-endpoint.name}.azureedge.net"
    ttl      = 60
  }

  record {
    hostname = "cdnverify"
    type     = "CNAME"
    address  = "cdnverify.${azurerm_cdn_endpoint.static-site-cdn-endpoint.name}.azureedge.net"
    ttl      = 60
  }
}

# Lets Encrypt Stuff
data "azurerm_key_vault" "certs" {
  name                = "acme-cdn-certs"
  resource_group_name = "shared-resources"
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.acme-email
}

resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  common_name               = var.domain-name
  subject_alternative_names = ["www.${var.domain-name}"]

  dns_challenge {
    provider = "namecheap"
  }
}

resource "azurerm_key_vault_certificate" "cert" {
  name         = "${local.safe-domain-name}-cert"
  key_vault_id = data.azurerm_key_vault.certs.id

  certificate {
    contents = acme_certificate.certificate.certificate_p12
  }
}

### Azure stuff
resource "random_string" "suffix" {
  length  = 8 - length(var.env)
  upper   = false
  special = false
}

resource "azurerm_resource_group" "static-site-rg" {
  name     = "${var.env}-${local.safe-domain-name}-static-site-rg-${random_string.suffix.result}"
  location = "eastus"
}

data "azuread_service_principal" "static-site-sp" {
  display_name = var.service-principal
}

resource "azurerm_role_assignment" "static-site-rg-role" {
  scope                = azurerm_resource_group.static-site-rg.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.static-site-sp.object_id
}

resource "azurerm_storage_account" "static-site-sa" {
  name                      = "${var.env}0static0site0sa0${random_string.suffix.result}"
  resource_group_name       = azurerm_resource_group.static-site-rg.name
  location                  = "eastus"
  account_tier              = "Standard"
  account_kind              = "StorageV2"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true

  static_website {
    index_document     = var.index-file
    error_404_document = var.error-file
  }
}

resource "azurerm_storage_blob" "blobs" {
  for_each               = fileset(var.content-dir, "/**/*")
  name                   = each.key
  storage_account_name   = azurerm_storage_account.static-site-sa.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = "${var.content-dir}/${each.key}"
  content_md5            = filemd5("${var.content-dir}/${each.key}")
  content_type           = lookup(tomap(local.mime_types), element(split(".", each.key), length(split(".", each.key)) - 1))
}


resource "azurerm_cdn_profile" "static-site-cdn-profile" {
  name                = "${var.env}-static-site-cp-${random_string.suffix.result}"
  location            = azurerm_resource_group.static-site-rg.location
  resource_group_name = azurerm_resource_group.static-site-rg.name
  sku                 = "Standard_Microsoft"
}

resource "azurerm_cdn_endpoint" "static-site-cdn-endpoint" {
  name                = "${var.env}-static-site-ce-${random_string.suffix.result}"
  profile_name        = azurerm_cdn_profile.static-site-cdn-profile.name
  location            = azurerm_resource_group.static-site-rg.location
  resource_group_name = azurerm_resource_group.static-site-rg.name

  origin_host_header = azurerm_storage_account.static-site-sa.primary_web_host

  is_http_allowed = false

  origin {
    name      = "static-site-main-endpoint"
    host_name = azurerm_storage_account.static-site-sa.primary_web_host
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "www-static-site-com" {
  name            = "www-${local.safe-domain-name}"
  cdn_endpoint_id = azurerm_cdn_endpoint.static-site-cdn-endpoint.id
  host_name       = "www.${var.domain-name}"

  user_managed_https {
    key_vault_secret_id = azurerm_key_vault_certificate.cert.id
  }

  depends_on = [namecheap_domain_records.static-site-dns]
}

resource "azurerm_cdn_endpoint_custom_domain" "static-site-com" {
  name            = local.safe-domain-name
  cdn_endpoint_id = azurerm_cdn_endpoint.static-site-cdn-endpoint.id
  host_name       = var.domain-name
  user_managed_https {
    key_vault_secret_id = azurerm_key_vault_certificate.cert.id
  }

  depends_on = [namecheap_domain_records.static-site-dns]
}
