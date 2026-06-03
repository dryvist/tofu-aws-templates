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
    condition     = strcontains(aws_iam_user_policy.tofu_admin.policy, "s3:CreateBucket") && !strcontains(aws_iam_user_policy.tofu_admin.policy, "s3:GetObject")
    error_message = "tofu-admin must create buckets but have no state-object access."
  }
}
