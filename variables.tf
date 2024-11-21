variable "env" {
  type    = string
  default = "dev"

}

variable "acme-email" {
  type    = string
  default = "test@example.com"
}

variable "domain-name" {
  type    = string
  default = "example.com"
}

variable "content-dir" {
  type    = string
  default = "content"
}
variable "index-file" {
  type    = string
  default = "index.html"
}

variable "error-file" {
  type    = string
  default = "404.html"
}

variable "keyvault-name" {
  type = string
}

variable "kv-rg" {
  type = string
}

variable "site-rg-name" {
  type = string
}

variable "cdn_profile_name" {
  type = string
}

variable "cdn_profile_rg_name" {
  type = string
}

variable "dns_providers" {
  type = list(string)
  default = [ "vultr" ]
}

variable "dns_challenge_provider" {
  type = string
}
