variable "aws_region" {
  description = "Region for the AWS provider. IAM is global; this only sets the provider endpoint."
  type        = string
  default     = "us-east-2"
}
