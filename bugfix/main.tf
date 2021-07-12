# In according to https://github.com/hashicorp/terraform-provider-aws/issues/13625
resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "publish-messages-function" // add a reference to your function name here
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API. the last one indicates where to send requests to.
  # see more detail https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html
  source_arn = "arn:aws:execute-api:ap-southeast-1:125065023022:[api-id]/*/*/*"
}

provider "aws" {
  region  = "ap-southeast-1"
}