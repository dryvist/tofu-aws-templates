output "state_bucket" {
  description = "Name of the S3 bucket for OpenTofu state."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_key_prefix" {
  description = "Prefix the consuming repo writes its state objects under."
  value       = "${var.project}/"
}

output "backend_config" {
  description = "S3 backend block ready to paste into the consuming repo's backend."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.state.bucket}"
        key          = "${var.project}/terraform.tfstate"
        region       = "${var.aws_region}"
        use_lockfile = true
        encrypt      = true
      }
    }
  EOT
}
