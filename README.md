# terraform-aws-template

Starting template for any new AWS-backed OpenTofu repo. The module
bootstraps everything a new repo needs to use AWS for state:

- S3 state bucket (SSE-S3 AES-256, versioned, public-access-blocked, TLS-only)
- IAM role `tf-<project>` with a combined trust policy:
  - the shared `terraform` base identity assumes it with **no MFA** — the
    aws-vault `source_profile` path, and the fleet's primary local/CI-source
    assume path (`source_principal_arns`)
  - GitHub Actions OIDC for CI (branch push + pull_request)
  - optional named operator IAM users, MFA enforced (`operator_user_arns`)
- IAM permissions policy scoped to that one bucket only, plus an optional
  `additional_policy_json` for projects that manage AWS resources beyond state

S3 native locking (`use_lockfile = true`, OpenTofu 1.10+) replaces
DynamoDB lock tables. SSE-S3 replaces SSE-KMS — same AES-256 cipher,
no per-key or per-API-call cost. State access is gated at the IAM role's
trust policy, not at a KMS key policy. Cross-region replication, access
logging, and event notifications are intentionally omitted to keep the backend
cheap — state durability comes from versioning.

**Tooling.** This fleet standardizes on [OpenTofu](https://opentofu.org)
(MPL 2.0), not Terraform (BUSL 1.1) — run everything with `tofu`. The
`terraform {}` blocks and the `tf-*` / `terraform` names below are HCL syntax
and fleet IAM identities, not the Terraform binary. [Terragrunt](https://terragrunt.gruntwork.io)
(MIT) is used only where multi-unit orchestration is needed; single-stack repos
like this one use plain OpenTofu.

Operator-facing walkthrough:
<https://docs.jacobpevans.com/infrastructure/terraform/aws-bootstrap>.

## Installation

This is a remote OpenTofu module. The consuming root module references it
by its git URL with a pinned ref:

```hcl
module "state_backend" {
  source = "git::https://github.com/dryvist/terraform-aws-template.git?ref=v0.2.0"

  # ... inputs (see API section below)
}
```

No `tofu init` step beyond what your root module already runs —
OpenTofu fetches the module on first init.

## Usage

In a directory owned by an AWS admin (one directory per project):

```hcl
terraform {
  required_version = ">= 1.10"

  # First apply runs with local state. Once the bucket exists,
  # uncomment this block and run `tofu init -migrate-state`
  # to lift the bootstrap state into the bucket it just created.
  #
  # backend "s3" {
  #   bucket       = "tfstate-<project>-<account-id>"
  #   key          = "_bootstrap/terraform.tfstate"
  #   region       = "us-east-2"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}

provider "aws" {
  region = "us-east-2"
}

module "state_backend" {
  source = "git::https://github.com/dryvist/terraform-aws-template.git?ref=v0.2.0"

  project        = "<project>"
  github_org     = "<github-org>"
  github_repo    = "<consuming-repo>"
  branch_pattern = "main"

  # The shared `terraform` base identity assumes the role with no MFA.
  source_principal_arns = [
    "arn:aws:iam::<account-id>:user/terraform",
  ]

  # Optional: named human operators (MFA enforced).
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
tofu init
tofu apply
tofu output -raw backend_config   # paste into consuming repo's backend.tf
```

After the first apply succeeds, uncomment the `backend "s3"` block above
(substituting the bucket name the module just emitted) and run
`tofu init -migrate-state` to lift the bootstrap state into the bucket.

## Prerequisites

- Admin AWS credentials in the shell (`aws sts get-caller-identity`
  returns an admin ARN).
- OpenTofu ≥ 1.10 (S3 native locking).
- GitHub Actions OIDC provider exists in the AWS account. Check:

  ```bash
  aws iam list-open-id-connect-providers \
    --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)]'
  ```

  Either create it once per account out of band (below), or set
  `create_oidc_provider = true` on the FIRST project bootstrapped in the
  account — leave it false everywhere else, since the provider is
  account-global and must exist exactly once:

  ```bash
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com
  ```

- A shared `terraform` base IAM user whose own policy grants `sts:AssumeRole`
  on `arn:aws:iam::<account-id>:role/tf-*`. Its ARN goes into
  `source_principal_arns` so aws-vault (`source_profile = terraform`) assumes
  the role with no MFA. This is the fleet's primary assume path.
- Optional: each operator has an IAM user with MFA enabled and the same
  `sts:AssumeRole` grant; their ARNs go into `operator_user_arns`.

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
- `aws_iam_role_policy.additional` — only when `additional_policy_json` is set
- `aws_iam_openid_connect_provider.github` — only when
  `create_oidc_provider = true` (otherwise the existing one is looked up)

## API

### Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `project` | `string` | — | Short kebab-case project id |
| `github_org` | `string` | — | GitHub org that owns the consuming repo |
| `github_repo` | `string` | — | Name of the consuming repo |
| `branch_pattern` | `string` | `main` | Branch CI may assume from on push (StringLike on OIDC sub) |
| `source_principal_arns` | `list(string)` | `[]` | Principal ARNs (the shared `terraform` base identity) allowed to AssumeRole with **no MFA** |
| `operator_user_arns` | `list(string)` | `[]` | IAM user ARNs allowed to AssumeRole with MFA |
| `additional_policy_json` | `string` | `""` | Optional inline IAM policy JSON for permissions beyond state |
| `create_oidc_provider` | `bool` | `false` | Create the account-global GitHub OIDC provider instead of looking it up |
| `aws_region` | `string` | `us-east-2` | Region for the state bucket |
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
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}
```

No `assume_role` block in `backend.tf` — aws-vault (local) and
`aws-actions/configure-aws-credentials@v4` (CI) perform the AssumeRole
before OpenTofu runs and export the role's STS credentials into the
subprocess environment. See the [consuming-repo guide][consuming] for
`~/.aws/config` and the GitHub Actions workflow shape.

[consuming]: https://docs.jacobpevans.com/infrastructure/terraform/consuming-repo

## Contributing

Issues and pull requests welcome on
<https://github.com/dryvist/terraform-aws-template>.

Before opening a PR:

- `direnv allow` to enter the devshell (`.envrc` → shared nix-devenv shell),
  which provides `tofu`, `tflint`, `terraform-docs`, and `pre-commit`.
- `pre-commit run --all-files` (fmt, validate, tflint, markdownlint).
- `tofu test` runs the plan-time naming-contract assertions in `tests/`.
- `examples/complete` is validated in CI; update it when inputs change.
- Keep changes scoped — this module provisions exactly one per-project state
  backend, nothing more.

Breaking changes ship as a new major version (`v1`, `v2`, …) so existing
consumers can stay pinned to a prior `ref` until they migrate.

## License

[Apache-2.0](LICENSE).
