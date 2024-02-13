terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.85.0"
    }
    namecheap = {
      source = "namecheap/namecheap"
      version = ">= 2.0.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47.0"
    }
  }
}
