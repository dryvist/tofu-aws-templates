output "tofu_user_arn" {
  description = "ARN of the tofu base identity. Pass to modules/iam `assume_principal_arns`."
  value       = aws_iam_user.tofu.arn
}

output "tofu_admin_user_arn" {
  description = "ARN of the standalone tofu-admin bucket-bootstrap identity."
  value       = aws_iam_user.tofu_admin.arn
}
