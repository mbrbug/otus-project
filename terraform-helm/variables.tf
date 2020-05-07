variable project {
  description = "Project ID"
  default = "notional-portal-276509"
}

variable stackdriverserviceAccountSecret {
  description = "stackdriver.serviceAccountSecret"
  default = "stackdriver-exporter-sa-json"
}

variable monitoring-namespace {
  description = "kubernetes monitoring namespace"
  default = "monitoring"
}