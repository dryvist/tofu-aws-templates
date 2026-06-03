data "aws_caller_identity" "current" {}

# GitHub Actions OIDC provider is account-global. By default we look up the
# existing one; set create_oidc_provider=true for the first project bootstrapped
# in a fresh account. thumbprint_list is intentionally omitted — AWS uses its own
# trusted root CAs for the GitHub IdP, so any configured thumbprint is unused.
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = local.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  bucket_name = "tfstate-${var.project}-${data.aws_caller_identity.current.account_id}"
  role_name   = "tf-${var.project}"

  github_oidc_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  tags = {
    Project     = var.project
    ManagedBy   = "OpenTofu"
    Repo        = "${var.github_org}/${var.github_repo}"
    Environment = "bootstrap"
  }
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}

resource "aws_s3_bucket_policy" "deny_insecure_transport" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.state.arn,
        "${aws_s3_bucket.state.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

resource "aws_iam_role" "terraform" {
  name = local.role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "GitHubOIDCBranchPush"
          Effect    = "Allow"
          Principal = { Federated = local.github_oidc_arn }
          Action    = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.branch_pattern}"
            }
          }
        },
        {
          Sid       = "GitHubOIDCPullRequest"
          Effect    = "Allow"
          Principal = { Federated = local.github_oidc_arn }
          Action    = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            }
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:pull_request"
            }
          }
        },
      ],
      # Base-identity assume path (no MFA): the shared `terraform` IAM user that
      # aws-vault uses as source_profile assumes this role with no prompt. This is
      # the fleet's primary local/CI-source assume path.
      length(var.source_principal_arns) > 0 ? [{
        Sid       = "BaseIdentityAssume"
        Effect    = "Allow"
        Principal = { AWS = var.source_principal_arns }
        Action    = "sts:AssumeRole"
      }] : [],
      # Optional direct human-operator assume path, MFA enforced.
      length(var.operator_user_arns) > 0 ? [{
        Sid       = "OperatorAssumeWithMFA"
        Effect    = "Allow"
        Principal = { AWS = var.operator_user_arns }
        Action    = "sts:AssumeRole"
        Condition = {
          Bool = { "aws:MultiFactorAuthPresent" = "true" }
        }
      }] : []
    )
  })
}

resource "aws_iam_role_policy" "state" {
  name = "${local.role_name}-state"
  role = aws_iam_role.terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketVersioning"]
        Resource = aws_s3_bucket.state.arn
      },
      {
        Sid      = "ObjectAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.state.arn}/*"
      },
    ]
  })
}

# Optional extra permissions for projects that manage AWS resources beyond their
# own state (e.g. Route53, EC2/VPC). State-only projects (like terraform-unifi)
# leave additional_policy_json empty and get the state policy alone.
resource "aws_iam_role_policy" "additional" {
  count  = var.additional_policy_json != "" ? 1 : 0
  name   = "${local.role_name}-additional"
  role   = aws_iam_role.terraform.id
  policy = var.additional_policy_json
}
