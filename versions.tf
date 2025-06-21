terraform {
  required_providers {
    mgc = {
      source  = "magalucloud/mgc"
      version = "0.33.0"
    }
  }
}

provider "mgc" {
  api_key = var.mgc_api_key
  region  = var.mgc_region
}
