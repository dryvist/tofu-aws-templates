output "state_bucket" {
  description = "Name of the S3 bucket for OpenTofu state."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "tf_role_arn" {
  description = "Role ARN to assume from the consuming repo's local dev shell and CI workflow."
  value       = aws_iam_role.terraform.arn
}

output "aws_region" {
  description = "Region where the state bucket lives."
  value       = var.aws_region
}

output "state_key_prefix" {
  description = "Prefix the consuming repo writes its state objects under."
  value       = "${var.project}/"
}

output "backend_config" {
  description = "S3 backend block ready to paste into the consuming repo's backend.tf."
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
