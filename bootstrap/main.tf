# ---------------------------------------------------------------------------
# Run once per AWS account, before anything in envs/.
#
# Creates the S3 bucket that holds Terraform state and the DynamoDB table that
# holds the lock. Without the lock, two people running apply at the same time
# corrupt the state file, and the damage is usually noticed much later.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  bucket = "${var.name}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket

  # State is the one thing that must never be casually destroyed. Recreating a
  # VPC is an afternoon; losing state means reconciling every resource by hand.
  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = local.bucket }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  # Versioning is what makes a corrupted or truncated state recoverable.
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State files hold plaintext values of everything Terraform manages, including
# any generated password. A public state bucket is a full account compromise.
data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid    = "DenyUnencryptedTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket     = aws_s3_bucket.state.id
  policy     = data.aws_iam_policy_document.state_tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.state]
}

resource "aws_dynamodb_table" "locks" {
  name         = "${var.name}-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = "${var.name}-locks" }
}
