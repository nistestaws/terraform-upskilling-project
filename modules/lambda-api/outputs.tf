output "api_endpoint" {
  description = "Base invoke URL of the HTTP API."
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "function_name" {
  description = "Name of the deployed Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the deployed Lambda function."
  value       = aws_lambda_function.this.arn
}
