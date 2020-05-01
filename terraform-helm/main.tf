provider "helm" {
}

resource "helm_release" "nginx-ingress" {
  name      = "nginx-ingress"
  chart     = "../nginx-ingress"
  namespace = "nginx-ingress"
  recreate_pods = true
}

resource "helm_release" "prometheus" {
  name      = "prometheus"
  chart     = "../prometheus"
  namespace = "monitoring"
  recreate_pods = true
}

resource "helm_release" "grafana" {
  name      = "grafana"
  chart     = "../grafana"
  namespace = "monitoring"
  recreate_pods = true
}

resource "helm_release" "efk" {
  name      = "efk"
  chart     = "../efk"
  namespace = "logging"
  recreate_pods = true
}
