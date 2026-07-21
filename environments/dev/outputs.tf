output "api_endpoint" {
  description = "Invoke URL for the dev API."
  value       = module.app.api_endpoint
}

output "function_name" {
  value = module.app.function_name
}
