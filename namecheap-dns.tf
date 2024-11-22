resource "namecheap_domain_records" "static-site-www" {
  count = contains(var.dns_providers, "namecheap") ? 1 : 0
  domain = var.domain-name
  mode   = "MERGE"

  record {
    hostname = "www"
    type     = "CNAME"
    address  = "${azurerm_cdn_endpoint.static-site-cdn-endpoint.name}.azureedge.net"
    ttl      = 60
  }
}

resource "namecheap_domain_records" "static-site-cdnverify" {
  count = contains(var.dns_providers, "namecheap") ? 1 : 0
  domain = var.domain-name
  mode   = "MERGE"
  record {
    hostname = "cdnverify"
    type     = "CNAME"
    address  = "cdnverify.${azurerm_cdn_endpoint.static-site-cdn-endpoint.name}.azureedge.net"
    ttl      = 60
  }
}
