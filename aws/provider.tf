provider "aws" {
  region  = "${var.region}"
  skip_requesting_account_id = false
}