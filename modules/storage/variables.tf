variable "project" {
  description = "Short kebab-case project id. Must match the modules/iam project so the bucket ARN aligns."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.project))
    error_message = "project must be lowercase kebab-case (letters, digits, and single hyphens)."
  }
}

variable "aws_region" {
  description = "Region for the state bucket. The consuming repo's backend must use the same region."
  type        = string
  default     = "us-east-2"
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which old state file versions are deleted from the bucket."
  type        = number
  default     = 90
}
