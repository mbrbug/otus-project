provider "helm" {
}

resource "kubernetes_namespace" "namespace-monitoring" {
  metadata {
    name = var.monitoring-namespace
  }
}

resource "kubernetes_namespace" "namespace-logging" {
  metadata {
    name = "logging"
  }
}

resource "kubernetes_namespace" "namespace-nginx-ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "kubernetes_secret" "stackdriver-exporter-sa-json" {
  metadata {
    name = "stackdriver-exporter-sa-json"
    namespace = var.monitoring-namespace
  }

  data = {
    "credentials.json" = "${file("~/gcp_keys/owner-gitlab_cinotional-portal-276509-25a6c8003fc1.json")}"
  }

  type = "Opaque"
}

resource "helm_release" "nginx-ingress" {
  name      = "nginx-ingress"
  chart     = "../nginx-ingress"
  namespace = "nginx-ingress"
  # recreate_pods = true
}

resource "helm_release" "prometheus" {
  name      = "prometheus"
  chart     = "../prometheus"
  namespace = var.monitoring-namespace
  # recreate_pods = true
  timeout = 600
}

resource "helm_release" "stackdriver-exporter" {
  name      = "stackdriver-exporter"
  chart     = "../stackdriver-exporter"
  namespace = var.monitoring-namespace
  # recreate_pods = true

  set {
    name  = "stackdriver.projectId"
    value = var.project
      }

  set {
    name  = "stackdriver.serviceAccountSecret"
    value = var.stackdriverserviceAccountSecret
      }
}

resource "helm_release" "grafana" {
  name      = "grafana"
  chart     = "../grafana"
  namespace = var.monitoring-namespace
  # recreate_pods = true
}

resource "helm_release" "efk-es-operator" {
  name       = "es-operator"
  #repository = "https://raw.githubusercontent.com/komljen/helm-charts/master/charts/" 
  namespace = "logging"
  chart      = "../elasticsearch-operator"
}

resource "helm_release" "efk" {
  name      = "efk"
  chart     = "../efk"
  namespace = "logging"
  # recreate_pods = true
  depends_on = [
    helm_release.efk-es-operator,
  ]
}
