variable "project" {
  description = "Short kebab-case project id. Matches the consuming repo's last path segment."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.project))
    error_message = "project must be lowercase kebab-case (letters, digits, and single hyphens)."
  }
}

variable "github_org" {
  description = "GitHub organization that owns the consuming repo."
  type        = string
}

variable "github_repo" {
  description = "Name of the consuming repo. Used in the OIDC sub-claim match."
  type        = string
}

variable "branch_pattern" {
  description = "Branch name CI is allowed to assume the role from on push events. Matched via StringLike against the OIDC sub claim."
  type        = string
  default     = "main"
}

variable "operator_user_arns" {
  description = "IAM user ARNs of human operators allowed to assume the role with MFA. Empty list disables operator AssumeRole entirely."
  type        = list(string)
  default     = []
}

variable "source_principal_arns" {
  description = "IAM principal ARNs allowed to assume this role WITHOUT MFA — the shared `terraform` base identity used as the aws-vault `source_profile` (and the CI source profile). This is the fleet's primary assume path: `terraform` -> `tf-<project>` with no prompt. Empty list disables it."
  type        = list(string)
  default     = []
}

variable "additional_policy_json" {
  description = "Optional inline IAM policy JSON granting permissions beyond the state bucket (e.g. Route53 for a DNS project, EC2/VPC for a compute project). Empty string attaches no extra policy. Pass jsonencode(...) or a data.aws_iam_policy_document.json."
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Create the account-global GitHub Actions OIDC provider instead of looking up an existing one. Set true for the FIRST project bootstrapped in a fresh account; leave false everywhere else (the provider is account-wide and must exist exactly once)."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "Region for the state bucket. The consuming repo's backend.tf must use the same region."
  type        = string
  default     = "us-east-2"
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which old state file versions are deleted from the bucket."
  type        = number
  default     = 90
}
