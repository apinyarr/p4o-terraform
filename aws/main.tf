# module "vpc" {
#   source = "terraform-aws-modules/vpc/aws"

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
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 2.0"

  name = "demo-dlq"
  create = var.create_sqs

  tags = {
    Service     = "demo-dlq"
    Environment = "prd"
  }
}

module "user_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 2.0"

  name = "demo-queue"
  create = var.create_sqs
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
  source = "terraform-aws-modules/lambda/aws"

  function_name = "publish-messages-function"
  description   = "Publish message to SQS"
  handler       = "message.lambda_handler"
  runtime       = "python3.8"

  create = var.create_lambda1

  source_path = "src/python/publish-message-function/message.py"
  create_role = false
  lambda_role = "arn:aws:iam::125065023022:role/p4o-lamda-sqs-cloudwatch"

  tags = {
    Name = "publish-message-lambda"
  }
}

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name          = "dev-http"
  description   = "My awesome HTTP API Gateway"
  protocol_type = "HTTP"

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  # Custom domain
  create_api_domain_name = false
  # domain_name                 = "terraform-aws-modules.modules.tf"
  # domain_name_certificate_arn = "arn:aws:acm:eu-west-1:052235179155:certificate/2b3a7ed9-05e1-4f9e-952b-27744ba06da6"

  # Access logs
  # default_stage_access_log_destination_arn = "arn:aws:logs:eu-west-1:835367859851:log-group:debug-apigateway"
  # default_stage_access_log_format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"

  # Routes and integrations
  integrations = {
    "POST /failure" = {
      lambda_arn             = "${module.lambda_function.lambda_function_arn}"
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
    }

    "$default" = {
      lambda_arn = "${module.lambda_function.lambda_function_arn}"
    }
  }

  tags = {
    Name = "http-apigateway"
  }
}