# terraform-aws-template

Starting template for any new AWS-backed Terraform / OpenTofu / Terragrunt
repo. The v0.1.0 module bootstraps everything a new repo needs to use AWS
for state:

- S3 state bucket (SSE-S3 AES-256, versioned, public-access-blocked, TLS-only)
- IAM role with combined trust policy: GitHub Actions OIDC for CI
  plus named operator IAM users with MFA for local dev
- IAM permissions policy scoped to that one bucket only —
  no other AWS access

S3 native locking (`use_lockfile = true`, Terraform 1.10+ / OpenTofu 1.10+)
replaces DynamoDB lock tables. SSE-S3 replaces SSE-KMS — same AES-256 cipher,
no per-key or per-API-call cost. State access is gated at the IAM role's
trust policy, not at a KMS key policy.

Operator-facing walkthrough:
<https://docs.jacobpevans.com/infrastructure/terraform/aws-bootstrap>.

## Installation

This is a remote Terraform module. The consuming root module references it
by its git URL with a pinned ref:

```hcl
module "state_backend" {
  source = "git::https://github.com/dryvist/terraform-aws-template.git?ref=v0.1.0"

  # ... inputs (see API section below)
}
```

No `terraform init` step beyond what your root module already runs —
Terraform fetches the module on first init.

## Usage

In a directory owned by an AWS admin (one directory per project):

```hcl
terraform {
  required_version = ">= 1.10"

  # First apply runs with local state. Once the bucket exists,
  # uncomment this block and run `terraform init -migrate-state`
  # to lift the bootstrap state into the bucket it just created.
  #
  # backend "s3" {
  #   bucket       = "tfstate-<project>-<account-id>"
  #   key          = "_bootstrap/terraform.tfstate"
  #   region       = "us-east-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}

provider "aws" {
  region = "us-east-1"
}

module "state_backend" {
  source = "git::https://github.com/dryvist/terraform-aws-template.git?ref=v0.1.0"

  project        = "<project>"
  github_org     = "<github-org>"
  github_repo    = "<consuming-repo>"
  branch_pattern = "main"

  operator_user_arns = [
    "arn:aws:iam::<account-id>:user/<operator>",
  ]
}

output "backend_config"   { value = module.state_backend.backend_config }
output "tf_role_arn"      { value = module.state_backend.tf_role_arn }
output "state_bucket"     { value = module.state_backend.state_bucket }
output "state_key_prefix" { value = module.state_backend.state_key_prefix }
```

Then:

```bash
terraform init
terraform apply
terraform output -raw backend_config   # paste into consuming repo's backend.tf
```

After the first apply succeeds, uncomment the `backend "s3"` block above
(substituting the bucket name the module just emitted) and run
`terraform init -migrate-state` to lift the bootstrap state into the bucket.

## Prerequisites

- Admin AWS credentials in the shell (`aws sts get-caller-identity`
  returns an admin ARN).
- Terraform ≥ 1.10 or OpenTofu ≥ 1.10 (S3 native locking).
- GitHub Actions OIDC provider exists in the AWS account. Check:

  ```bash
  aws iam list-open-id-connect-providers \
    --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)]'
  ```

  Create once per account if missing:

  ```bash
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com
  ```

- Each operator has an IAM user with MFA enabled, plus a policy granting
  only `sts:AssumeRole` on `arn:aws:iam::<account-id>:role/tf-*`. The
  operator's IAM user ARN goes into `operator_user_arns`.

## What gets provisioned

- `aws_s3_bucket.state` — `tfstate-<project>-<account-id>`
- `aws_s3_bucket_versioning.state` — enabled
- `aws_s3_bucket_server_side_encryption_configuration.state` — AES256 / SSE-S3
- `aws_s3_bucket_public_access_block.state` — all four block flags on
- `aws_s3_bucket_lifecycle_configuration.state` — expire noncurrent
  versions after 90 days (configurable)
- `aws_s3_bucket_policy.deny_insecure_transport` — TLS-only
- `aws_iam_role.terraform` — `tf-<project>` with the combined trust policy
- `aws_iam_role_policy.state` — scoped to the one bucket only

## API

### Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `project` | `string` | — | Short kebab-case project id |
| `github_org` | `string` | — | GitHub org that owns the consuming repo |
| `github_repo` | `string` | — | Name of the consuming repo |
| `branch_pattern` | `string` | `main` | Branch CI may assume from on push (StringLike on OIDC sub) |
| `operator_user_arns` | `list(string)` | `[]` | IAM user ARNs allowed to AssumeRole with MFA |
| `aws_region` | `string` | `us-east-1` | Region for the state bucket |
| `noncurrent_version_expiration_days` | `number` | `90` | Lifecycle expiry for old state versions |

### Outputs

| Name | Description |
| --- | --- |
| `state_bucket` | S3 bucket name |
| `state_bucket_arn` | S3 bucket ARN |
| `tf_role_arn` | Role ARN for backend, local dev, and CI |
| `aws_region` | Region where the bucket lives |
| `state_key_prefix` | Prefix for the consuming repo's state objects |
| `backend_config` | Ready-to-paste `backend "s3" {}` block for the consuming repo |

## Consuming repo

The consuming repo's `backend.tf` ends up looking like (paste the
`backend_config` output):

```hcl
terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "tfstate-<project>-<account-id>"
    key          = "<project>/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

No `assume_role` block in `backend.tf` — aws-vault (local) and
`aws-actions/configure-aws-credentials@v4` (CI) perform the AssumeRole
before Terraform runs and export the role's STS credentials into the
subprocess environment. See the [consuming-repo guide][consuming] for
`~/.aws/config` and the GitHub Actions workflow shape.

[consuming]: https://docs.jacobpevans.com/infrastructure/terraform/consuming-repo

## Contributing

Issues and pull requests welcome on
<https://github.com/dryvist/terraform-aws-template>.

Before opening a PR:

- Run `terraform fmt -recursive` to canonicalize formatting.
- Run `terraform validate` (no apply needed) to confirm the module parses.
- Keep changes scoped — this module exists to provision exactly one
  per-project state backend, nothing more.

Breaking changes ship as a new major version (`v1`, `v2`, …) so existing
consumers can stay pinned to a prior `ref` until they migrate.

## License

[Apache-2.0](LICENSE).
