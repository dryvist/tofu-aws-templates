data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  role_name = "tf-${var.project}"

  # Constructed as a string (not a bucket resource) so this IAM config has NO
  # dependency on the storage config — they are applied by different identities,
  # in separate states. The bucket is created by tofu-admin via modules/storage.
  bucket_arn = "arn:aws:s3:::tfstate-${var.project}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Project     = var.project
    ManagedBy   = "OpenTofu"
    Repo        = "${var.github_org}/${var.github_repo}"
    Environment = "bootstrap"
  }
}

resource "aws_iam_role" "this" {
  name = local.role_name
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "GitHubOIDCBranchPush"
          Effect    = "Allow"
          Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
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
          Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
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
      # Base-identity assume path (no MFA): the shared `tofu` user that aws-vault
      # uses as source_profile assumes this role with no prompt.
      length(var.assume_principal_arns) > 0 ? [{
        Sid       = "BaseIdentityAssume"
        Effect    = "Allow"
        Principal = { AWS = var.assume_principal_arns }
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

# State access only: modify objects in the project's own bucket. NO CreateBucket
# and no bucket-configuration actions — that is tofu-admin's job (no criss-cross).
resource "aws_iam_role_policy" "state" {
  name = "${local.role_name}-state"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketVersioning"]
        Resource = local.bucket_arn
      },
      {
        Sid      = "ObjectAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${local.bucket_arn}/*"
      },
    ]
  })
}

# Optional extra permissions for projects that manage AWS resources beyond state.
resource "aws_iam_role_policy" "additional" {
  count  = var.additional_policy_json != "" ? 1 : 0
  name   = "${local.role_name}-additional"
  role   = aws_iam_role.this.id
  policy = var.additional_policy_json
}
