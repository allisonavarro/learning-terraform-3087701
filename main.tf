terraform {
  cloud {
    organization = "allisonavarro"
    workspaces {
      name = "learning-terraform"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "hello_bucket" {
  bucket = "hello-world-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_object" "hello_file" {
  bucket = aws_s3_bucket.hello_bucket.id
  key    = "hello.txt"
  content = "Hello World from Terraform Cloud + AWS!"
}

resource "random_id" "suffix" {
  byte_length = 4
}

output "bucket_name" {
  value = aws_s3_bucket.hello_bucket.bucket
}
