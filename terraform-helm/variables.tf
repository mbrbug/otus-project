variable project {
  description = "Project ID"
  default = "docker-270618"
}

variable stackdriverserviceAccountSecret {
  description = "stackdriver.serviceAccountSecret"
  default = "stackdriver-exporter-sa-json"
}

variable monitoring-namespace {
  description = "kubernetes monitoring namespace"
  default = "monitoring"
}