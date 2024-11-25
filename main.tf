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

# Lets Encrypt Stuff
data "azurerm_key_vault" "certs" {
  name                = var.keyvault-name
  resource_group_name = var.kv-rg
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
    provider = var.dns_challenge_provider
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

data "azurerm_resource_group" "static-site-rg" {
  name = var.site-rg-name
}

resource "azurerm_storage_account" "static-site-sa" {
  name                      = "${var.env}0${substr(replace(local.safe-domain-name, "-", ""), 0, (24 - 2 - length(var.env) - length(random_string.suffix.result)))}0${random_string.suffix.result}"
  resource_group_name       = data.azurerm_resource_group.static-site-rg.name
  location                  = "eastus"
  account_tier              = "Standard"
  account_kind              = "StorageV2"
  account_replication_type  = "LRS"
  https_traffic_only_enabled = true

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

data "azurerm_cdn_profile" "static-site-cdn-profile" {
  name                = var.cdn_profile_name
  resource_group_name = var.cdn_profile_rg_name
}

resource "azurerm_cdn_endpoint" "static-site-cdn-endpoint" {
  name                = "${var.env}-${local.safe-domain-name}-${random_string.suffix.result}"
  profile_name        = data.azurerm_cdn_profile.static-site-cdn-profile.name
  location            = data.azurerm_resource_group.static-site-rg.location
  resource_group_name = data.azurerm_resource_group.static-site-rg.name

  origin_host_header = azurerm_storage_account.static-site-sa.primary_web_host

  is_http_allowed = true

  origin {
    name      = "static-site-main-endpoint"
    host_name = azurerm_storage_account.static-site-sa.primary_web_host
  }

	delivery_rule {
		name = "HttpsRedirect"
		order = 1

		request_scheme_condition {
			match_values = toset([ "HTTP" ] )
		}

		url_redirect_action {
			redirect_type = "PermanentRedirect"
			protocol = "Https"
		}
	}
}

resource "azurerm_cdn_endpoint_custom_domain" "www-static-site-com" {
  name            = "www-${local.safe-domain-name}"
  cdn_endpoint_id = azurerm_cdn_endpoint.static-site-cdn-endpoint.id
  host_name       = "www.${var.domain-name}"

  user_managed_https {
    key_vault_secret_id = azurerm_key_vault_certificate.cert.secret_id
  }

  depends_on = [vultr_dns_record.static-site-www]
}

