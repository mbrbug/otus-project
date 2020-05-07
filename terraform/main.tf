provider "google" {
  project = var.project
  region  = "us-central1"
  credentials = file("~/gcp_keys/owner-gitlab_cinotional-portal-276509-25a6c8003fc1.json")
}

resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = var.location
  project = var.project
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
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

resource "google_container_node_pool" "primary_nodes" {
  name       = "my-node-pool"
  location   = var.location
  project = var.project
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    preemptible  = false
    machine_type = "n1-standard-2"
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
