############ Create all IAM resources ##############

# Create p4o-lambda-producer role for producer lambda
resource "aws_iam_role" "lambda_producer_role" {
  name = "p4o-lambda-producer"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach AWS managed policy AWSLambdaBasicExecutionRole to p4o-lambda-producer role
resource "aws_iam_role_policy_attachment" "lambda_log_attachment" {
    role = "${aws_iam_role.lambda_producer_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach AWS managed policy AmazonSQSFullAccess to p4o-lambda-producer role
resource "aws_iam_role_policy_attachment" "lambda_producer_attachment" {
    role = "${aws_iam_role.lambda_producer_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# Create p4o-lambda-consumer role for consumer lambda
resource "aws_iam_role" "lambda_consumer_role" {
  name = "p4o-lambda-consumer"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach AWS managed policy AWSLambdaBasicExecutionRole to p4o-lambda-consumer role
resource "aws_iam_role_policy_attachment" "lambda2_log_attachment" {
    role = "${aws_iam_role.lambda_consumer_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach AWS managed policy AmazonSQSFullAccess to p4o-lambda-consumer role
resource "aws_iam_role_policy_attachment" "lambda_consumer_attachment" {
    role = "${aws_iam_role.lambda_consumer_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# Attach AWS managed policy AmazonKinesisFirehoseFullAccess to p4o-lambda-consumer role
resource "aws_iam_role_policy_attachment" "lambda_firehose_attachment" {
    role = "${aws_iam_role.lambda_consumer_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFirehoseFullAccess"
}

# Create p4o-apigw role for api gateway
resource "aws_iam_role" "apigw_lambda_role" {
  name = "p4o-apigw"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach AWS managed policy AWSLambdaBasicExecutionRole to p4o-apigw role
resource "aws_iam_role_policy_attachment" "apigw_log_attachment" {
    role = "${aws_iam_role.apigw_lambda_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create p4o-firehose role for kinesis firehose
resource "aws_iam_role" "firehose_role" {
  name = "p4o-firehose"

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

# Attach AWS managed policy AmazonS3FullAccess to p4o-firehose role
resource "aws_iam_role_policy_attachment" "firehose_policy_attachment" {
    role = aws_iam_role.firehose_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Create p4o-glue role for glue
resource "aws_iam_role" "glue_role" {
  name = "p4o-glue"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Attach AWS managed policy AWSGlueServiceRole to p4o-glue role
resource "aws_iam_role_policy_attachment" "glue_service" {
    role = "${aws_iam_role.glue_role.id}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Attach inline policy to p4o-glue role
resource "aws_iam_role_policy" "my_s3_policy" {
  name = "p4o-glue-s3"
  role = "${aws_iam_role.glue_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::p4o-s3-bucket",
        "arn:aws:s3:::p4o-s3-bucket/*"
      ]
    }
  ]
}
EOF
}

# data for get aws account id
data "aws_caller_identity" "current" {}

# In according to https://github.com/hashicorp/terraform-provider-aws/issues/13625
# Create lambda permission for api gateway
resource "aws_lambda_permission" "apigw_permission" {
  # count = var.grant_lambda_for_apigw ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "publish-messages-function" // add a reference to your function name here
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API. the last one indicates where to send requests to.
  # see more detail https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html
  source_arn = "arn:aws:execute-api:ap-southeast-1:${data.aws_caller_identity.current.account_id}:${module.api_gateway.apigatewayv2_api_id}/*"
}

############ Create all SQS resources ##############

# Create Dead-letter Queue for user queue below
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

# Create user queue
module "user_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 2.0"

  name = "demo-queue"
  create = var.create_sqs
  redrive_policy = jsonencode({
    deadLetterTargetArn = "${module.user_dlq.this_sqs_queue_arn}" // refer to Dead-letter Queue
    maxReceiveCount = 3
  })

  tags = {
    Service     = "demo-queue"
    Environment = "prd"
  }
}

############ Create all Lambda resources ##############

# Create lambda function for producer
module "lambda_function_produce_sqs" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "publish-messages-function"
  description   = "Publish message to SQS"
  handler       = "message.lambda_handler"
  runtime       = "python3.8"

  create = var.create_lambda1

  source_path = "src/python/publish-message-function/message.py"
  create_role = false
  lambda_role = "${aws_iam_role.lambda_producer_role.arn}"

  attach_policy_json = true
  
  tags = {
    Name = "publish-message-lambda"
  }
}

# Create lambda function for consumer
module "lambda_function_consume_sqs" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "consume-messages-function"
  description   = "Consume message from SQS"
  handler       = "process.lambda_handler"
  runtime       = "python3.8"

  create = var.create_lambda2

  source_path = "src/python/consume-message-function/process.py"
  create_role = false
  lambda_role = "${aws_iam_role.lambda_consumer_role.arn}"

  attach_policy_json = true

  tags = {
    Name = "consume-message-lambda"
  }
}

# map consumer lambda function with Dead-letter Queue
resource "aws_lambda_event_source_mapping" "dlq_consumer" {
  event_source_arn = "${module.user_dlq.this_sqs_queue_arn}"
  function_name    = "${module.lambda_function_consume_sqs.lambda_function_arn}"
}

############ Create all API Gateway resources ##############

# Create log group in Cloudwatch for api gateway below
resource "aws_cloudwatch_log_group" "apigw_log_group" {
  name = "/aws/apigw/accesslog"
}

# Create api gateway
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
    }

    "ANY /success" = {
      lambda_arn             = "${module.lambda_function_produce_sqs.lambda_function_arn}"
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
    }
  }

  tags = {
    Name = "http-apigateway"
  }
}

############ Create all Kinesis resources ##############

# Create s3 bucket for storing output from kinesis firehose
resource "aws_s3_bucket" "bucket" {
  bucket = "p4o-s3-bucket"
  acl    = "private"
}

# Create kinesis firehose as a Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "test_stream" {
  name        = "terraform-kinesis-firehose-test-stream"
  destination = "s3"

  s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.bucket.arn
  }
}

############ Create all Glue resources ##############

# Create glue catalog database for glue crawler below
resource "aws_glue_catalog_database" "aws_glue_catalog_database" {
  name = "my-glue-catalog-database"
}

# Create glue crawler for reading from s3
resource "aws_glue_crawler" "glue_crawler_example" {
  database_name = aws_glue_catalog_database.aws_glue_catalog_database.name
  name          = "my-glue-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.bucket.bucket}"
  }

  # provisioner "local-exec" {
  #   command = "aws glue start-crawler --name ${self.name}"
  # }
  schedule = "cron(5 * * * ? *)"
}