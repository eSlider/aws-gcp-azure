output "base_url" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "blob_uri" {
  value = "s3://${aws_s3_bucket.events.bucket}"
}
