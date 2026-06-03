# foundation

Account-level identities for the state-backend model. Applied **once per
account** by `iam-user` (which has `IAMFullAccess`). Creates two users — no S3,
no buckets here.

| User | Purpose | Policy |
| --- | --- | --- |
| `tofu` | everyday base identity; assumes the per-project `tf-*` roles | `sts:AssumeRole` on `tf-*` |
| `tofu-admin` | standalone, one-time bucket creator | create + configure `tfstate-*` buckets; **no object access, no DeleteBucket** |

Access keys are created out of band and stored with `aws-vault add` — never in
state.

## Installation

Run directly from this directory as `iam-user` (local state):

```bash
aws-vault exec --no-session iam-user -- tofu init
```

## Usage

```bash
aws-vault exec --no-session iam-user -- tofu apply
# then create + store each user's access key (keeps secrets out of state):
aws iam create-access-key --user-name tofu        # store via: aws-vault add tofu
aws iam create-access-key --user-name tofu-admin  # store via: aws-vault add tofu-admin
```

Outputs `tofu_user_arn` (feed into `modules/iam` `assume_principal_arns`) and
`tofu_admin_user_arn`.
