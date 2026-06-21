provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  tags = {
    ManagedBy   = "OpenTofu"
    Environment = "foundation"
  }
}

# Everyday base identity. Holds the only routinely-injected credential and
# assumes the per-project tf-* roles (no MFA). Create its access key out of band
# and store it with `aws-vault add tofu` — never commit the key to state.
resource "aws_iam_user" "tofu" {
  name = "tofu"
  tags = local.tags
}

resource "aws_iam_user_policy" "tofu_assume" {
  name = "assume-project-roles"
  user = aws_iam_user.tofu.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeProjectRoles"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/tf-*"
    }]
  })
}

# Standalone, one-time infrastructure admin. Creates and configures state
# buckets only — NO state-object access and NO DeleteBucket, so it never
# crosses paths with the per-project tf-* roles. Used directly via its own
# credential (`aws-vault add tofu-admin`); it is not assumed from `tofu`.
resource "aws_iam_user" "tofu_admin" {
  name = "tofu-admin"
  tags = local.tags
}

resource "aws_iam_user_policy" "tofu_admin" {
  name = "state-bucket-bootstrap"
  user = aws_iam_user.tofu_admin.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Bucket-level admin only: s3:* scoped to the bucket ARN (not the /*
        # object ARN). Object actions require the .../* resource, which is
        # intentionally absent — so tofu-admin can never read or write state
        # objects. This breadth is needed because the aws_s3_bucket resource
        # reads back ~20 bucket sub-configs (CORS, website, logging, …) on refresh.
        Sid      = "BucketAdmin"
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "arn:aws:s3:::tfstate-*"
      },
      {
        # Never tear down a state bucket from this identity.
        Sid      = "DenyBucketDeletion"
        Effect   = "Deny"
        Action   = "s3:DeleteBucket"
        Resource = "arn:aws:s3:::tfstate-*"
      },
    ]
  })
}
