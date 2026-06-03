# modules/iam

Per-project `tf-<project>` role. Applied by **`iam-user`**. Grants
**state-object access only** to the project's bucket — it never creates or
configures buckets (that is `tofu-admin`'s job via `modules/storage`). Trust:
GitHub OIDC (CI) + the `tofu` base identity (no MFA) + optional MFA operators.

## Installation

```hcl
module "tf_role" {
  source = "git::https://github.com/dryvist/tofu-aws-templates.git//modules/iam?ref=v0.3.0"
}
```

## Usage

```hcl
module "tf_role" {
  source      = "git::https://github.com/dryvist/tofu-aws-templates.git//modules/iam?ref=v0.3.0"
  project     = "unifi"
  github_org  = "dryvist"
  github_repo = "tofu-unifi"

  # The tofu base identity assumes this role with no MFA.
  assume_principal_arns = ["arn:aws:iam::<account-id>:user/tofu"]
}
```

Apply as `iam-user`. The state bucket itself is created separately by
`tofu-admin` via `modules/storage`.

| Input | Default | Description |
| --- | --- | --- |
| `project` | — | kebab-case project id |
| `github_org` / `github_repo` | — | consuming repo (OIDC sub-claim) |
| `branch_pattern` | `main` | branch CI may assume from |
| `assume_principal_arns` | `[]` | no-MFA assumers (the `tofu` user) |
| `operator_user_arns` | `[]` | MFA-gated operators |
| `additional_policy_json` | `""` | extra inline policy beyond state |

Outputs: `role_arn`, `role_name`.
