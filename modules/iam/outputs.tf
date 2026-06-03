output "role_arn" {
  description = "ARN of the tf-<project> role to assume for state access (local dev + CI)."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the tf-<project> role."
  value       = aws_iam_role.this.name
}
