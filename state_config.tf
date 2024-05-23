terraform {
  backend "s3" {
    bucket  = "[SEU_BUCKET]"
    key     = "terraform.tfstate"
    region  = "us-east-1"
    profile = "[SEU_PROFILE]"
  }
}
