terraform {
  backend "local" {
  }

  required_providers {
    aws = {
      version = "~> 5.67.0"
      source  = "hashicorp/aws"
    }

  }

  required_version = ">= 1.9.5"
}


provider "aws" {
  region = var.aws_region
}

resource "aws_kms_key" "tf_state_encrypt_key" {
  description             = "SSE-KMS key used to encrypt the TF state S3 bucket"
  deletion_window_in_days = 15
  enable_key_rotation     = true
  rotation_period_in_days = 180
}

resource "aws_s3_bucket" "tf_state" {
  bucket        = var.tf_state_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_encryption" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tf_state_encrypt_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state_bucket_access" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "allow_ssl_request_only" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    effect    = "Deny"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.tf_state.bucket}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_state_bucket_policy" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.allow_ssl_request_only.json
}

resource "aws_dynamodb_table" "tf_state_db_table" {
  name                        = "tf-state-locking"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "LockID"
  deletion_protection_enabled = true

  attribute {
    name = "LockID"
    type = "S"
  }
}
