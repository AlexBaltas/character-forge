variable "aws_region" {
  description = "AWS region for Charactar Forge"
  type        = string
  default     = "us-east-2"
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI for Character Forge"
  type        = string
  default     = "ami-0032668e4af0aa746"
}