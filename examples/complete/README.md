# Complete example

Shows a project consuming both modules — `modules/iam` (the `tf-<project>` role)
and `modules/storage` (the state bucket). In production they are applied by
different identities (`iam-user` and `tofu-admin`); here they are validated
together for documentation. Account IDs are the AWS documentation placeholder
(`123456789012`).

## Installation

Consumes the modules at the repo root via relative `source = "../../modules/*"`.
`tofu init` fetches the AWS provider.

## Usage

```bash
tofu init -backend=false
tofu validate
```

To bootstrap a real project, apply the two modules separately with the right
identity (`iam-user` for `iam`, `tofu-admin` for `storage`), then paste
`tofu output -raw backend_config` into the consuming repo's backend.
