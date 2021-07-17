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

resource "aws_iam_role_policy_attachment" "lambda_log_attachment" {
    role = "${aws_iam_role.lambda_producer_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_producer_attachment" {
    role = "${aws_iam_role.lambda_producer_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

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

resource "aws_iam_role_policy_attachment" "apigw_log_attachment" {
    role = "${aws_iam_role.apigw_lambda_role.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# In according to https://github.com/hashicorp/terraform-provider-aws/issues/13625
resource "aws_lambda_permission" "apigw_permission" {
  # count = var.grant_lambda_for_apigw ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "publish-messages-function" // add a reference to your function name here
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API. the last one indicates where to send requests to.
  # see more detail https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html
  source_arn = "${module.api_gateway.apigatewayv2_api_arn}/*"
}

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
  lambda_role = "${aws_iam_role.lambda_producer_role.arn}"
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

resource "aws_cloudwatch_log_group" "apigw_log_group" {
  name = "/aws/apigw/accesslog"
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
      # credentials_arn = "arn:aws:iam::125065023022:role/p4o-apigw"
      # authorization_type = "AWS_IAM"
    }

    "ANY /success" = {
      lambda_arn             = "${module.lambda_function_produce_sqs.lambda_function_arn}"
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
      # credentials_arn = "arn:aws:iam::125065023022:role/p4o-apigw"
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