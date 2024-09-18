variable "tf_state_bucket_name" {
  description = "Name to be given for the TF state locking S3 bucket"
  type        = string
  nullable    = false
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

