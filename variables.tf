variable "env" {
  type    = string
  default = "dev"

}

variable "acme-email" {
  type=string
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
