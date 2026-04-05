terraform {
  backend "s3" {
    bucket  = "valmir-terraform"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    profile = "bia-terraform"
  }
}
