variable "environment" {

description = "Environment name (eg. dev, staging). Used in resource names and tags"
type = string
}

variable "function_name"{
    description = "Base name for the Lambda function."
    type = string
}

variable "lambda_zip_path" {
    description = "Path to the lambda deployment package (.zip)."
    type = string
}

variable "lambda_handler" {
  description = "Lambda handler entrypoint."
  type        = string
  default     = "app.handler"
}

variable "lambda_runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.12"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}