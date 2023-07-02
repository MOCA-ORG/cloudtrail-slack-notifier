provider "aws" {
  region = "ap-northeast-1"
}

terraform {
  required_version = "~> 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.6.0"
    }
  }

  backend "s3" {}
}
