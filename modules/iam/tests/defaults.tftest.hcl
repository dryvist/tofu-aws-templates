# Plan-time assertions against a mocked AWS provider (no credentials, no apply).

mock_provider "aws" {}

variables {
  project               = "example"
  github_org            = "dryvist"
  github_repo           = "tofu-example"
  assume_principal_arns = ["arn:aws:iam::123456789012:user/tofu"]
}

run "role_naming_and_object_only_policy" {
  command = plan

  assert {
    condition     = aws_iam_role.this.name == "tf-example"
    error_message = "Role name must be tf-<project>."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.state.policy, "s3:PutObject") && !strcontains(aws_iam_role_policy.state.policy, "s3:CreateBucket")
    error_message = "tf-<project> must have object access only — never CreateBucket."
  }

  assert {
    condition     = strcontains(aws_iam_role.this.assume_role_policy, "arn:aws:iam::123456789012:user/tofu")
    error_message = "Trust policy must allow the tofu base identity to assume (no MFA)."
  }
}

run "no_extra_policy_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.additional) == 0
    error_message = "additional_policy_json defaults to empty."
  }
}
