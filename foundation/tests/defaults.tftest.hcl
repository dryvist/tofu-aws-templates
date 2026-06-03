# Plan-time assertions against a mocked AWS provider (no credentials, no apply).

mock_provider "aws" {}

run "creates_both_identities" {
  command = plan

  assert {
    condition     = aws_iam_user.tofu.name == "tofu"
    error_message = "Base identity must be the user 'tofu'."
  }

  assert {
    condition     = aws_iam_user.tofu_admin.name == "tofu-admin"
    error_message = "Bucket bootstrap identity must be the standalone user 'tofu-admin'."
  }

  assert {
    condition     = strcontains(aws_iam_user_policy.tofu_admin.policy, "s3:*") && strcontains(aws_iam_user_policy.tofu_admin.policy, "s3:DeleteBucket") && !strcontains(aws_iam_user_policy.tofu_admin.policy, "tfstate-*/*")
    error_message = "tofu-admin must have bucket-level admin (s3:* on the bucket ARN), deny DeleteBucket, and no object (/*) access."
  }
}
