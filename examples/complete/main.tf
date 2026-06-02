terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# Complete example: bootstrap the state backend + tf-<project> role for a
# consuming repo. Validated in CI (never applied) — the account IDs below are
# the AWS documentation placeholder, not real.
module "state_backend" {
  source = "../../"

  project     = "example"
  github_org  = "dryvist"
  github_repo = "terraform-example"

  # Fleet base identity: the shared `terraform` IAM user assumes the role with
  # NO MFA (this is the aws-vault source_profile path). Primary local/CI-source path.
  source_principal_arns = ["arn:aws:iam::123456789012:user/terraform"]

  # Optional: named human operators may assume directly, MFA enforced.
  operator_user_arns = ["arn:aws:iam::123456789012:user/operator"]

  # Optional: grant permissions beyond the state bucket. State-only projects
  # (e.g. terraform-unifi) omit this and get the state policy alone. Scope to
  # specific ARNs — never "*" for restrictable actions.
  additional_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "Route53Zone"
      Effect   = "Allow"
      Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets"]
      Resource = "arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"
    }]
  })
}

output "backend_config" {
  description = "Backend block to paste into the consuming repo's backend.tf."
  value       = module.state_backend.backend_config
}

output "tf_role_arn" {
  description = "ARN of the tf-<project> role."
  value       = module.state_backend.tf_role_arn
}

output "state_bucket" {
  description = "Name of the state bucket."
  value       = module.state_backend.state_bucket
}

output "state_key_prefix" {
  description = "Prefix the consuming repo writes state under."
  value       = module.state_backend.state_key_prefix
}
