from airflow import DAG
from airflow.providers.databricks.operators.databricks import DatabricksSubmitRunOperator, DatabricksRunNowOperator
from datetime import datetime, timedelta 

#Define params for Submit Run Operator
new_cluster = {
    'spark_version': '10.4.x-scala2.12',
    'num_workers': 2,
    'node_type_id': 'i3.xlarge',
     "aws_attributes": {
        "instance_profile_arn": "arn:aws:iam::683819638661:instance-profile/databricks-bruno-instance-profile"
    }
}

notebook_task1 = {
    'notebook_path': '/Users/brunoof1@gmail.com/gluenotebooks',
}

notebook_task2 = {
    'notebook_path': '/Users/goneswet@amazon.com/covid-bronze',
}

#Define params for Run Now Operator
notebook_params = {
    "Variable":5
}

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=2)
}

with DAG('databricks_dag',
    start_date=datetime(2022, 10, 5),
    schedule_interval='@daily',
    catchup=False,
    default_args=default_args
    ) as dag:

    opr_show_dbs = DatabricksSubmitRunOperator(
        task_id='show-dbs',
        databricks_conn_id='databricks_default',
        new_cluster=new_cluster,
        notebook_task=notebook_task1
    )
    opr_covid_bronze = DatabricksSubmitRunOperator(
        task_id='covid-bronze',
        databricks_conn_id='databricks_default',
        new_cluster=new_cluster,
        notebook_task=notebook_task2
    )
    opr_show_dbs >> opr_covid_bronze