terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.69.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.2.4"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}
