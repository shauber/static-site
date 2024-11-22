# data "vultr_dns_domain" "static-site-wwww" {
#   domain = var.domain-name
# }
resource "vultr_dns_record" "static-site-www" {
  count = contains(var.dns_providers, "vultr") ? 1 : 0
  domain = var.domain-name
  name = "www"
  type     = "CNAME"
  data  = "${azurerm_cdn_endpoint.static-site-cdn-endpoint.name}.azureedge.net"
  ttl      = 60
}
resource "vultr_dns_record" "static-site-cdnverify" {
  count = contains(var.dns_providers, "vultr") ? 1 : 0
  domain = var.domain-name
  name = "cdnverify"
  type     = "CNAME"
  data  = "cdnverify.${azurerm_cdn_endpoint.static-site-cdn-endpoint.name}.azureedge.net"
  ttl      = 60
}