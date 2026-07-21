terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "nishrisa-terraform-state-us-east-1"
    key            = "staging/terraform.tfstate"   # <-- CHANGED
    region         = "us-east-1"
    dynamodb_table = "nishrisa-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
