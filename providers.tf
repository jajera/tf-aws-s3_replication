terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.10.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

provider "aws" {
  alias  = "southeast2"
  region = "ap-southeast-2"
}
