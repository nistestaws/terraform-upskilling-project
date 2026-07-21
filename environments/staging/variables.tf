variable "aws_region" {
  description = "AWS region for this environment."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "staging"   # <-- CHANGED
}

variable "function_name" {
  description = "Base name for the Lambda function."
  type        = string
  default     = "hello"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package."
  type        = string
  default     = "../../app/function.zip"
}
