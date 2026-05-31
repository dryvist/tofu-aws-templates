variable "project" {
  description = "Short kebab-case project id. Matches the consuming repo's last path segment (e.g. \"proxmox\" for \"terraform-proxmox\")."
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

variable "aws_region" {
  description = "Region for the state bucket. The consuming repo's backend.tf must use the same region."
  type        = string
  default     = "us-east-1"
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which old state file versions are deleted from the bucket."
  type        = number
  default     = 90
}
