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

# resource "aws_iam_role" "p4o_role" {
#   name = "p4o-lambda-sqs-cloudwatch"

#   # Terraform's "jsonencode" function converts a
#   # Terraform expression result to valid JSON syntax.
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         "Action": [
#             "sqs:*"
#         ],
#         "Effect": "Allow",
#         "Resource": "*"
#       },
#       {
#         "Effect": "Allow",
#         "Action": [
#             "logs:CreateLogGroup",
#             "logs:CreateLogStream",
#             "logs:PutLogEvents"
#         ],
#         "Resource": "*"
#       }
#     ]
#   })

#   tags = {
#     tag-key = "tag-value"
#   }
# }

# resource "aws_iam_role" "p4o_sqs_role" {
#   name = "p4o-lambda-sqs"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "",
#       "Effect": "Allow",
#       "Principal": {
#         "Service": [
#           "sqs.amazonaws.com"
#         ]
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_role" "p4o_lambda_role" {
#   name = "p4o-lambda-cloudwatch"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "",
#       "Effect": "Allow",
#       "Principal": {
#         "Service": [
#           "lambda.amazonaws.com"
#         ]
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_role_policy_attachment" "sqs_policy_attachment" {
#     role = "${aws_iam_role.p4o_sqs_role.name}"
#     policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
# }

# resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
#     role = "${aws_iam_role.p4o_lambda_role.name}"
#     policy_arn = "arn:aws:iam::aws:policy/AWSLambdaBasicExecutionRole"
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

module "lambda_function_produce_sqs" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "publish-messages-function"
  description   = "Publish message to SQS"
  handler       = "message.lambda_handler"
  runtime       = "python3.8"

  create = var.create_lambda1

  source_path = "src/python/publish-message-function/message.py"
  create_role = false
  lambda_role = "arn:aws:iam::125065023022:role/p4o-lambda-sqs-cloudwatch"
  # lambda_role = "${aws_iam_role.p4o_sqs_role.arn}"

  attach_policy_json = true

  # allowed_triggers = {
  #   APIGatewayAny = {
  #     service    = "apigateway"
  #     source_arn = "arn:aws:execute-api:ap-southeast-1:125065023022:${var.apigw_id}/*/*/*"
  #   }
  # }

  tags = {
    Name = "publish-message-lambda"
  }
}

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name          = "prd-http"
  create        = var.create_apigw
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
  default_stage_access_log_destination_arn = "arn:aws:logs:ap-southeast-1:125065023022:log-group:/aws/apigw/accesslog"
  default_stage_access_log_format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"

  # Routes and integrations
  integrations = {
    "ANY /failure" = {
      lambda_arn             = "${module.lambda_function_produce_sqs.lambda_function_arn}"
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
      # credentials_arn = "arn:aws:iam::125065023022:role/p4o-apigw-lambda"
      # authorization_type = "AWS_IAM"
    }

    "ANY /success" = {
      lambda_arn             = "${module.lambda_function_produce_sqs.lambda_function_arn}"
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
      # credentials_arn = "arn:aws:iam::125065023022:role/p4o-apigw-lambda"
      # authorization_type = "AWS_IAM"
    }

    # "$default" = {
      # lambda_arn = "${module.lambda_function.lambda_function_arn}"
      # credentials_arn = "arn:aws:iam::125065023022:role/p4o-apigw-lambda"
      # authorization_type = "AWS_IAM"
    # }
  }

  tags = {
    Name = "http-apigateway"
  }
}

module "lambda_function_consume_sqs" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "consume-messages-function"
  description   = "Consume message from SQS"
  handler       = "process.lambda_handler"
  runtime       = "python3.8"

  create = var.create_lambda2

  source_path = "src/python/consume-message-function/process.py"
  create_role = false
  lambda_role = "arn:aws:iam::125065023022:role/p4o-lambda-sqs-cloudwatch"
  # lambda_role = "${aws_iam_role.p4o_lambda_role.arn}"

  attach_policy_json = true

  tags = {
    Name = "consume-message-lambda"
  }
}

# In according to https://github.com/hashicorp/terraform-provider-aws/issues/13625
resource "aws_lambda_permission" "apigw_permission" {
  count = var.grant_lambda_for_apigw ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "publish-messages-function" // add a reference to your function name here
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API. the last one indicates where to send requests to.
  # see more detail https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html
  source_arn = "arn:aws:execute-api:ap-southeast-1:125065023022:${var.apigw_id}/*"
}

resource "aws_lambda_event_source_mapping" "dlq_consumer" {
  count = var.create_event_source_mapping ? 1 : 0
  event_source_arn = var.source_sqs_arn //aws_sqs_queue.sqs_queue_test.arn
  function_name    = var.lambda_function_arn //aws_lambda_function.example.arn
}

# resource "aws_kinesis_stream" "test_stream" {
#   name             = "terraform-kinesis-test"
#   shard_count      = 1
#   retention_period = 24

#   shard_level_metrics = [
#     "IncomingBytes",
#     "OutgoingBytes",
#   ]

#   tags = {
#     Environment = "test"
#   }
# }

resource "aws_s3_bucket" "bucket" {
  bucket = "p4o-s3-bucket"
  acl    = "private"
}

resource "aws_iam_role" "firehose_role" {
  name = "firehose_test_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {
    role = "firehose_test_role"
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_kinesis_firehose_delivery_stream" "test_stream" {
  name        = "terraform-kinesis-firehose-test-stream"
  destination = "s3"

  s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.bucket.arn
  }
}