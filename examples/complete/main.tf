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

# Documentation/validation example only. In practice the two modules are applied
# by DIFFERENT identities in separate states: `iam` by iam-user, `storage` by
# tofu-admin. Account IDs are the AWS documentation placeholder.

module "iam" {
  source = "../../modules/iam"

  project     = "example"
  github_org  = "dryvist"
  github_repo = "tofu-example"

  # The tofu base identity assumes the role with no MFA.
  assume_principal_arns = ["arn:aws:iam::123456789012:user/tofu"]

  # Optional: grant permissions beyond state (scope to specific ARNs, never "*").
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

module "storage" {
  source = "../../modules/storage"

  project    = "example"
  aws_region = "us-east-2"
}

output "tf_role_arn" {
  description = "ARN of the tf-<project> role (from modules/iam)."
  value       = module.iam.role_arn
}

output "backend_config" {
  description = "Backend block to paste into the consuming repo (from modules/storage)."
  value       = module.storage.backend_config
}

output "state_bucket" {
  description = "Name of the state bucket (from modules/storage)."
  value       = module.storage.state_bucket
}
