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
  description = "Branch name CI may assume the role from on push events. Matched via StringLike against the OIDC sub claim."
  type        = string
  default     = "main"
}

variable "assume_principal_arns" {
  description = "IAM principal ARNs allowed to assume this role WITHOUT MFA — the shared `tofu` base identity used as the aws-vault source_profile. This is the fleet's primary local/CI-source assume path."
  type        = list(string)
  default     = []
}

variable "operator_user_arns" {
  description = "IAM user ARNs of human operators allowed to assume the role with MFA. Empty list disables operator AssumeRole entirely."
  type        = list(string)
  default     = []
}

variable "additional_policy_json" {
  description = "Optional inline IAM policy JSON granting permissions beyond the state bucket (e.g. Route53, EC2/VPC). Empty string attaches no extra policy."
  type        = string
  default     = ""
}
