resource "aws_dynamodb_table" "patients" {
  name           = "mediconnect-patients"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "patientId"
  
  attribute {
    name = "patientId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name               = "email-index"
    hash_key           = "email"
    projection_type    = "ALL"
  }
}

resource "aws_dynamodb_table" "appointments" {
  name           = "mediconnect-appointments"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "appointmentId"
  
  attribute {
    name = "appointmentId"
    type = "S"
  }
  
  attribute {
    name = "patientId"
    type = "S"
  }
  
  attribute {
    name = "dateTime"
    type = "S"
  }

  global_secondary_index {
    name               = "patient-index"
    hash_key           = "patientId"
    range_key          = "dateTime"
    projection_type    = "ALL"
  }
}

resource "aws_dynamodb_table" "interactions" {
  name         = "mediconnect-drug-interactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "drug1_id"
  range_key    = "drug2_id"

  attribute {
    name = "drug1_id"
    type = "S"
  }
  
  attribute {
    name = "drug2_id"
    type = "S"
  }
}

resource "aws_s3_bucket" "recordings" {
  bucket = "mediconnect-recordings-${var.project}-${var.environment}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings_enc" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# IoT Core & Analytics
resource "aws_kinesis_stream" "iot_vitals" {
  name        = "mediconnect-iot-vitals"
  shard_count = 1
  retention_period = 24
  
  encryption_type = "KMS"
  kms_key_id      = var.kms_key_arn
}

resource "aws_timestreamwrite_database" "iot_db" {
  database_name = "mediconnect-iot"
  kms_key_id    = var.kms_key_arn
}

resource "aws_timestreamwrite_table" "vital_signs" {
  database_name = aws_timestreamwrite_database.iot_db.database_name
  table_name    = "vital_signs"

  retention_properties {
    magnetic_store_retention_period_in_days = 90
    memory_store_retention_period_in_hours  = 24
  }
}
