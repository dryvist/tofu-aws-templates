# Complete example

Bootstraps a state backend and `tf-<project>` role for a consuming repo,
exercising every input: `source_principal_arns` (no-MFA base identity assume),
`operator_user_arns` (MFA), and `additional_policy_json` (extra permissions).

## Installation

This example consumes the module at the repo root via a relative
`source = "../../"`. No extra installation — `tofu init` fetches the AWS provider.

## Usage

Validated in CI with `tofu validate` (never applied; the account IDs are the AWS
documentation placeholder `123456789012`):

```bash
tofu init -backend=false
tofu validate
```

To actually bootstrap a project, copy this directory, set real inputs, run with
admin credentials (`aws-vault exec iam-user -- tofu apply`), then paste
`tofu output -raw backend_config` into the consuming repo's `backend.tf`.
