output "sql_instance_name" { value = google_sql_database_instance.postgres.name }
output "spanner_instance_id" { value = google_spanner_instance.rx_spanner.name }
