# description = "Contains Stage Airflow Definition"

# lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_kms_key" "infra" {
  key_id = var.kms_infra_key_id
}
data "aws_kms_key" "data" {
  key_id = var.kms_data_key_id
}

#PRIVATE_ONLY
locals {
    dag_s3_path        = "dags/"
    execution_role_arn = "arn:aws:iam::683819638661:role/service-role/mwaa-role-serasa"
    name               = "SerasaAirflow"
    security_group_ids = "sg-02008cb229082f401"
    subnet_ids         = ["subnet-014d176cf7629adae", "subnet-0629c36ed20f5cbe1",]
    source_bucket_arn  = join(":", ["arn:aws:s3::", var.airflow_bucket])
    kms_key            = data.aws_kms_key.data.arn
    webserver_access_mode = "PUBLIC_ONLY" 
    airflow_version      = "2.0.2"
    environment_class    = "mw1.small"
    min_workers           = 1
    max_workers           = 10
}

resource "aws_mwaa_environment" "mwaa" {
    
    airflow_configuration_options = {
        "core.default_task_retries" = 16
        "core.parallelism"          = 1
        "core.load_default_connections" = "true"
        "core.load_examples"            = "true"
        "webserver.dag_default_view"    = "tree"
        "webserver.dag_orientation"     = "TB"
        "logging.logging_level"         = "INFO"
        }
    
    min_workers           = local.min_workers
    max_workers           = local.max_workers
    dag_s3_path           = local.dag_s3_path
    execution_role_arn    = local.execution_role_arn
    name                  = local.name
    kms_key               = local.kms_key
    webserver_access_mode = local.webserver_access_mode
    airflow_version       = local.airflow_version
    environment_class     = local.environment_class
    
    network_configuration {
        security_group_ids = [local.security_group_ids]
        subnet_ids         = local.subnet_ids
        }
    
    source_bucket_arn = local.source_bucket_arn
    
    logging_configuration {

        dag_processing_logs {
            enabled   = true
            log_level = "DEBUG"
            }

        scheduler_logs {
            enabled   = true
            log_level = "INFO"
        }

        task_logs {
            enabled   = true
            log_level = "WARNING"
        }

        webserver_logs {
            enabled   = true
            log_level = "ERROR"
        }

        worker_logs {
            enabled   = true
            log_level = "CRITICAL"
        }
    }
}
