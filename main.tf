terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.34.0"
    }
  }
  backend "gcs" {
    bucket = "serverless-datalab-terraform-state"
    prefix = "terraform/state"
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project = var.project_id
  region  = var.region_name
}

variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "region_name" {
  type        = string
  description = "The GCP region name"
}

variable "credentials_file" {
  type        = string
  description = "The path to the GCP service account key JSON file"
  default     = "sa_key.json"
}

variable "deploy_version" {
  type        = string
  description = "The version of the app to deploy"
  default     = "latest"
}

# Cloud SQL instance
resource "google_sql_database_instance" "mysql_instance" {
  name             = "serverless-datalab-mysql8"
  database_version = "MYSQL_8_0"
  region           = var.region_name

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true
      require_ssl  = false

      authorized_networks {
        value = "0.0.0.0/0"
        name  = "all"
      }
    }

    backup_configuration {
      enabled = true
    }

    deletion_protection_enabled = false
  }
}

resource "google_sql_database" "mysql_db" {
  name       = "serverless_datalab_db"
  instance   = google_sql_database_instance.mysql_instance.name
}

# Cloud Storage bucket
resource "google_storage_bucket" "datalab_bucket" {
  name     = "serverless-datalab-assets"
  location = var.region_name
}

# Cloud Run service for RStudio
resource "google_cloud_run_service" "rstudio" {
  name     = "serverless-datalab-rstudio"
  location = var.region_name

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/data-lab:${var.deploy_version}"
        # image = "gcr.io/${var.project_id}/data-lab:2342b5e4780d1fa27fa244bab886e1c58c274a4a"

        ports {
          container_port = 8787
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }
    }
  }
}

resource "google_cloud_run_service_iam_binding" "allowUnauthenticated" {
  project = google_cloud_run_service.rstudio.project
  location = google_cloud_run_service.rstudio.location
  service = google_cloud_run_service.rstudio.name
  role = "roles/run.invoker"
  members = [
    "allUsers",
  ]
}

output "RStudio_url" {
  value = "${google_cloud_run_service.rstudio.status[0].url}"
}

output "SQL_url" {
  value = "${google_sql_database_instance.mysql_instance.connection_name}"
}
