module "app" {
  source = "../../modules/lambda-api"

  environment     = var.environment
  function_name   = var.function_name
  lambda_zip_path = var.lambda_zip_path

  tags = {
    Project     = "terraform-upskilling"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
