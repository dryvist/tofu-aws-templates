# modules/storage

Per-project state bucket: S3 (SSE-S3 AES-256, versioned, public-access-blocked,
TLS-only, lifecycle expiry). S3-native locking (`use_lockfile`) — no DynamoDB.
Applied by **`tofu-admin`** (the standalone bucket creator). Cross-region
replication, access logging, and event notifications are intentionally omitted
to keep the backend cheap; durability comes from versioning.

## Installation

```hcl
module "state_bucket" {
  source = "git::https://github.com/dryvist/tofu-aws-templates.git//modules/storage?ref=v0.3.0"
}
```

## Usage

```hcl
module "state_bucket" {
  source     = "git::https://github.com/dryvist/tofu-aws-templates.git//modules/storage?ref=v0.3.0"
  project    = "unifi"
  aws_region = "us-east-2"
}

output "backend_config" { value = module.state_bucket.backend_config }
```

Apply as `tofu-admin` (`aws-vault exec tofu-admin -- tofu apply`). Paste
`tofu output -raw backend_config` into the consuming repo's backend. The
matching `tf-<project>` role (object access) is created separately via
`modules/iam`.

Outputs: `state_bucket`, `state_bucket_arn`, `state_key_prefix`, `backend_config`.
