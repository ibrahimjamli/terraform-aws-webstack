# ---------------------------------------------------------------------------
# Application data bucket plus, optionally, a bucket to receive its access
# logs. Every control that S3 leaves off by default is turned on here:
# encryption, versioning, a full public-access block, TLS-only access and
# lifecycle expiry for superseded versions.
# ---------------------------------------------------------------------------

locals {
  tags        = merge(var.tags, { Module = "storage" })
  data_bucket = "${var.name}-data-${var.bucket_suffix}"
  log_bucket  = "${var.name}-logs-${var.bucket_suffix}"
}

# --- log bucket ------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = local.log_bucket
  force_destroy = var.force_destroy
  tags          = merge(local.tags, { Name = local.log_bucket, Purpose = "access-logs" })
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # The data bucket had this and the log bucket did not, which Checkov
    # caught: incomplete uploads are invisible in the console but still billed.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

# S3 log delivery writes with an ACL, which the bucket owner enforced setting
# would otherwise reject.
resource "aws_s3_bucket_ownership_controls" "logs" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# --- data bucket -----------------------------------------------------------

resource "aws_s3_bucket" "data" {
  bucket        = local.data_bucket
  force_destroy = var.force_destroy
  tags          = merge(local.tags, { Name = local.data_bucket, Purpose = "application-data" })
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    # Cuts KMS request costs when the default is later swapped for a CMK.
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "tidy-superseded-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    # Incomplete uploads are invisible in the console but still billed.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.data]
}

resource "aws_s3_bucket_logging" "data" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = aws_s3_bucket.data.id
  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "s3-access/"
}

resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bucket policies are additive to IAM; this one denies rather than allows, so
# it cannot be bypassed by a permissive identity policy elsewhere.
data "aws_iam_policy_document" "data_tls_only" {
  statement {
    sid    = "DenyUnencryptedTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  policy = data.aws_iam_policy_document.data_tls_only.json

  # Applying a policy before the public-access block is in place would briefly
  # leave the bucket in a weaker state than intended.
  depends_on = [aws_s3_bucket_public_access_block.data]
}
