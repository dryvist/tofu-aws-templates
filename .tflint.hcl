# dryvist organization-wide tflint canonical.
#
# Single source of truth for tflint configuration across every dryvist
# terraform/opentofu repo. Consumer repos either fetch this file at
# scaffold time (non-Nix path) or have the Nix-side `fetch-shared-configs`
# helper materialize it into the repo at devShell entry (Nix path).
#
# The terraform plugin is enabled with the `recommended` preset. The
# rules below are an explicit superset of the most-common per-repo
# variants (terraform-proxmox / terraform-github style): documented
# variables/outputs, required providers/version. AWS / GCP / Azure
# plugins stay opt-in per repo because they pull large rulesets and
# slow tflint considerably on repos that don't target that cloud.
#
# Schema: https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/config.md

config {
  format           = "compact"
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Documentation-discipline rules (most-shared canonical).
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}
