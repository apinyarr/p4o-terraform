# module "vpc" {
#   source = "./modules/terraform-aws-vpc"

#   name = "pamelo-vpc"
#   cidr = "10.0.0.0/16"

#   azs             = ["ap-southeast-1a"]
#   private_subnets = ["10.0.1.0/24"]
#   public_subnets  = ["10.0.101.0/24"]

#   enable_dns_hostnames = true
#   enable_dns_support = true
#   create_igw = false

#   tags = {
#     Terraform = "true"
#     Environment = "prd"
#   }
# }

module "user_dlq" {
  source  = "./modules/terraform-aws-sqs"
  version = "~> 2.0"

  name = "demo-dlq"

  tags = {
    Service     = "demo-dlq"
    Environment = "prd"
  }
}

module "user_queue" {
  source  = "./modules/terraform-aws-sqs"
  version = "~> 2.0"

  name = "demo-queue"
  redrive_policy = jsonencode({
    deadLetterTargetArn = "${module.user_dlq.this_sqs_queue_arn}"
    maxReceiveCount = 3
  })

  tags = {
    Service     = "demo-queue"
    Environment = "prd"
  }
}

module "lambda_function" {
  source = "./modules/terraform-aws-lambda"

  function_name = "function-publish-messages"
  description   = "Publish message to SQS"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "../src/message"

  lambda_role = "arn:aws:iam::125065023022:user/Producer"

  tags = {
    Name = "publish-message-lambda"
  }
}