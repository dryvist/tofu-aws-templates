# Plan-time assertions against a mocked AWS provider (no credentials, no apply).

mock_provider "aws" {}

variables {
  project    = "example"
  aws_region = "us-east-2"
}

run "bucket_naming_and_backend" {
  command = plan

  assert {
    condition     = startswith(aws_s3_bucket.state.bucket, "tfstate-example-")
    error_message = "State bucket must be tfstate-<project>-<account-id>."
  }

  assert {
    condition     = strcontains(output.backend_config, "key          = \"example/terraform.tfstate\"")
    error_message = "backend_config must key state under <project>/terraform.tfstate."
  }
}
