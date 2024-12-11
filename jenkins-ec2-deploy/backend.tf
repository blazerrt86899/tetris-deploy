terraform {
  backend "s3" {
    bucket = "tetris-project-backend-0099888"
    key    = "Jenkins/terraform.tfstate"
    region = "us-east-1"
  }
}