output "patients_table_name" { value = aws_dynamodb_table.patients.name }
output "recordings_bucket_name" { value = aws_s3_bucket.recordings.id }
output "iot_db_name" { value = aws_timestreamwrite_database.iot_db.database_name }
