output "api_invoke_url" {
  description = "Public URL for the health endpoint"
  value       = "${aws_apigatewayv2_api.health.api_endpoint}/health"
}

output "lambda_function_name" {
  description = "Deployed Lambda function name"
  value       = aws_lambda_function.health.function_name
}
