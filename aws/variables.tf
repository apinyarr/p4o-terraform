variable "region" {
    description = "aws region"
    type = string
    default = "ap-southeast-1"
}

variable "create_sqs" {
    description = "option to provision sqs"
    type = bool
    default = true
}

variable "create_lambda1" {
    description = "option to provision lambda1"
    type = bool
    default = true
}

variable "create_lambda2" {
    description = "option to provision lambda2"
    type = bool
    default = true
}

variable "create_apigw" {
    description = "option to provision apigw"
    type = bool
    default = true
}