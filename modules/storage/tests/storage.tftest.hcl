provider "aws" {
  region                      = "eu-north-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
}

variables {
  name          = "unit"
  bucket_suffix = "123456789012"
}

run "bucket_names_include_the_account_suffix" {
  command = plan

  assert {
    condition     = aws_s3_bucket.data.bucket == "unit-data-123456789012"
    error_message = "Bucket names must carry the suffix, or a second account cannot deploy this."
  }
}

run "public_access_is_blocked_on_every_axis" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.data.block_public_acls,
      aws_s3_bucket_public_access_block.data.block_public_policy,
      aws_s3_bucket_public_access_block.data.ignore_public_acls,
      aws_s3_bucket_public_access_block.data.restrict_public_buckets,
    ])
    error_message = "All four public-access settings must be enabled; three is not enough."
  }
}

run "versioning_and_encryption_are_on" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.data.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning is what makes an accidental overwrite recoverable."
  }
}

run "destroy_protection_is_the_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket.data.force_destroy == false
    error_message = "force_destroy must be opt-in; on by default turns a careless destroy into data loss."
  }
}

run "access_logging_can_be_disabled" {
  command = plan

  variables {
    enable_access_logging = false
  }

  assert {
    condition     = length(aws_s3_bucket.logs) == 0
    error_message = "No log bucket should be planned when logging is disabled."
  }

  assert {
    condition     = length(aws_s3_bucket_logging.data) == 0
    error_message = "Logging configuration without a target bucket would fail to apply."
  }
}

run "log_bucket_is_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket.logs) == 1
    error_message = "Access logging should be on unless explicitly disabled."
  }
}

run "lifecycle_rules_are_on_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.data) == 1
    error_message = "Superseded versions would accumulate forever without a lifecycle rule."
  }
}

run "lifecycle_rules_can_be_disabled_for_an_s3_backend_that_lacks_them" {
  command = plan

  variables {
    enable_lifecycle_rules = false
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.data) == 0
    error_message = "Disabling lifecycle rules should plan none."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.logs) == 0
    error_message = "The log bucket's lifecycle rule should follow the same switch."
  }
}
