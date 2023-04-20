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
  name             = "serverless-datalab-mysql"
  database_version = "MYSQL_8_0"
  region           = var.region_name

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled = true
    }

    backup_configuration {
      enabled = true
    }
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

        resources {
          limits = {
            cpu    = "1"
            memory = "2Gi"
          }
        }
      }

      service_account_name = google_service_account.rstudio_sa.email
    }
  }
}

resource "google_cloud_run_service_iam_member" "allow_authenticated" {
  project  = google_cloud_run_service.rstudio.project
  location = google_cloud_run_service.rstudio.location
  service  = google_cloud_run_service.rstudio.name
  role     = "roles/run.invoker"
  member   = "allAuthenticatedUsers"
}

# Custom IAM role and service account
resource "google_project_iam_custom_role" "rstudio_custom_role" {
  role_id     = "rstudioCustomRole"
  title       = "RStudio Custom Role"
  description = "Custom role for RStudio service account in the ServerlessDataLab project"
  permissions = [
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.create",
    "storage.objects.update",
    "storage.objects.delete",
    "cloudsql.instances.get",
    "cloudsql.instances.list",
  ]
}

resource "google_service_account" "rstudio_sa" {
  account_id   = "serverless-datalab-rstudio"
  display_name = "RStudio Service Account"
}

resource "google_project_iam_member" "rstudio_sa_member" {
  project = var.project_id
  role    = "projects/${var.project_id}/roles/${google_project_iam_custom_role.rstudio_custom_role.role_id}"
  member  = "serviceAccount:${google_service_account.rstudio_sa.email}"
}
