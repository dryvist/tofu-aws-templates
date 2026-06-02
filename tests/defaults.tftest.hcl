# Plan-time assertions against a mocked AWS provider (no credentials, no apply).
# Pins the naming contract consuming repos depend on: bucket, role, state key.

mock_provider "aws" {}

variables {
  project               = "example"
  github_org            = "dryvist"
  github_repo           = "terraform-example"
  source_principal_arns = ["arn:aws:iam::123456789012:user/terraform"]
}

run "naming_contract" {
  command = plan

  assert {
    condition     = aws_iam_role.terraform.name == "tf-example"
    error_message = "Role name must be tf-<project>."
  }

  assert {
    condition     = startswith(aws_s3_bucket.state.bucket, "tfstate-example-")
    error_message = "State bucket must be tfstate-<project>-<account-id>."
  }

  assert {
    condition     = strcontains(output.backend_config, "key          = \"example/terraform.tfstate\"")
    error_message = "backend_config must key state under <project>/terraform.tfstate."
  }
}

run "no_extra_policy_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.additional) == 0
    error_message = "additional_policy_json defaults to empty — no extra policy attached."
  }
}
