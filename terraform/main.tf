provider "google" {
  # Версия провайдера
#  version = "2.15"
  # ID проекта
#  project = docker-270618
#  region  = "us-central1"
}

resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = "us-central1-c"
  project = "docker-270618"
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 2
  enable_legacy_abac = true
 
  ip_allocation_policy {}

  logging_service = "none"
  monitoring_service = "none" 

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  location   = "us-central1-c"
  project = "docker-270618"
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = true
    machine_type = "n1-standard-4"
    disk_size_gb = 50
 

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

#resource "helm_release" "nginx-ingress" {
#  name  = "nginx-ingress"
#  chart = "stable/nginx-ingress"
#}
