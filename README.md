# tofu-aws-templates

OpenTofu modules that bootstrap an AWS state backend under a
**separation-of-duties** identity model. Each consuming repo gets its own state
bucket and a `tf-<project>` role that can only *modify* its state — never create
infrastructure.

This fleet runs on [OpenTofu](https://opentofu.org) (MPL 2.0), not Terraform
(BUSL 1.1) — run everything with `tofu`. The `terraform {}` blocks and `tf-*`
names are HCL syntax and IAM identities, not the Terraform binary.
[Terragrunt](https://terragrunt.gruntwork.io) (MIT) is used only for multi-unit
orchestration; single-stack consumers use plain OpenTofu.

## Identity model (no criss-crossing)

| Identity | Kind | Creates / can do | Must NOT |
| --- | --- | --- | --- |
| `iam-user` | user | apply IAM configs (`foundation` + `modules/iam`): roles, users, policies | touch S3 / state |
| `tofu` | user (base) | everyday inject; `sts:AssumeRole` on `tf-*` (no MFA) | act on resources directly |
| `tofu-admin` | user (standalone) | create + configure `tfstate-*` buckets (one-time) | state-object access; `DeleteBucket` |
| `tf-<project>` | role (assumed from `tofu` + OIDC) | **modify** state objects in its own bucket | create / configure / delete buckets |

You inject one everyday credential — `tofu` — and assume any `tf-*` role from it
(the profiles in `~/.aws/config` are just role maps). `tofu-admin` is a separate
occasional inject for bucket creation. `iam-user` creates the identities.

## Components

| Path | Applied by | Creates |
| --- | --- | --- |
| `foundation/` | `iam-user` (once per account) | `tofu` + `tofu-admin` users + their policies |
| `modules/iam/` | `iam-user` (per project) | `tf-<project>` role — object access only |
| `modules/storage/` | `tofu-admin` (per project) | `tfstate-<project>-<acct>` bucket (SSE-S3, versioned, TLS-only, `use_lockfile`) |

## Installation

Modules are sourced by git URL with a pinned ref:

```hcl
module "tf_role" {
  source = "git::https://github.com/dryvist/tofu-aws-templates.git//modules/iam?ref=v0.3.0"
}
```

## Usage

Order to onboard a project (see `examples/complete`):

1. **Once per account** — `iam-user` applies `foundation/` → `tofu` + `tofu-admin`
   users. Create each access key and store it with `aws-vault add` (keeps
   secrets out of state).
2. **Per project** — `iam-user` applies a config sourcing `modules/iam` →
   the `tf-<project>` role (trusts the `tofu` user + GitHub OIDC).
3. **Per project** — `tofu-admin` applies a config sourcing `modules/storage` →
   the bucket. Paste `tofu output -raw backend_config` into the consuming repo.
4. The consuming repo's stack runs as `tf-<project>`, assumed via `tofu`.

## Prerequisites

- `iam-user` (IAMFullAccess) for steps 1–2; `tofu-admin` (created in step 1) for step 3.
- OpenTofu ≥ 1.10 (S3-native locking).
- A GitHub Actions OIDC provider in the account (the iam module looks it up).

## Contributing

Before opening a PR (in the devshell — `direnv allow`):

- `tofu fmt -check -recursive`, `pre-commit run --all-files`.
- `tofu test` in `foundation/`, `modules/iam/`, `modules/storage/`.
- `examples/complete` is validated in CI.
- Breaking changes ship as a new version so consumers can stay pinned.

## License

[Apache-2.0](LICENSE).

---

> Part of a [larger ecosystem of ~40 repos](https://docs.jacobpevans.com) — see how it all fits together.
