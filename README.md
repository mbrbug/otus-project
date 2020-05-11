# Otus DevOps project

За основу взят Hipster Shop: Cloud-Native Microservices Demo Application от Google  
Изменен сервис frontend:  
на порту 9090 сервис отдает метрики: latency bucket, количество кодов состояния HTTP (200, 302, 404, 500), запрос по типу (GET, POST)  
Удалено создание LoadBalancer при деплое. Вместо него добавлено создание nginx ingress. С адресами production, staging, review.  

frontend/chart/templates/ingress.yamlhttp://nnmclub.to/forum/login.php

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  labels:
    app: {{ template "frontend.fullname" . }}
  name: {{ template "frontend.fullname" . }}
  annotations:
spec:
  rules:
    - host: {{ .Release.Namespace }}.homembr.ru
      http:
        paths:
          - path: /
            backend:
              serviceName: frontend
              servicePort: {{ .Values.service.externalPort }}

```

Установлены gitlab, prometheus, grafana, elastiksearch, fluent-bit, kibana  
настроены pipeline для создания новых образов микросервисов, их проверки в namespace review  
а также выкатки приложения в namespace staging и production

Namespace для разделения служб: logging, monitoring, nginx-ingress, production, staging, review

видео
<https://youtu.be/EzFXsRzpmH0>

Репозиторий проекта
<https://github.com/mbrbug/otus-project>

Список публичных repo в gitlab ()  
<https://gitlab.com/andrewmbr/shop-deploy>  
<https://gitlab.com/andrewmbr/shippingservice>  
<https://gitlab.com/andrewmbr/redis-cart>  
<https://gitlab.com/andrewmbr/recommendationservice>  
<https://gitlab.com/andrewmbr/productcatalogservice>  
<https://gitlab.com/andrewmbr/paymentservice>  
<https://gitlab.com/andrewmbr/loadgenerator>  
<https://gitlab.com/andrewmbr/frontend>  
<https://gitlab.com/andrewmbr/emailservice>  
<https://gitlab.com/andrewmbr/currencyservice>  
<https://gitlab.com/andrewmbr/checkoutservice>  
<https://gitlab.com/andrewmbr/cartservice>  
<https://gitlab.com/andrewmbr/adservice>  

### 1. Устанавливаем, если нет локально, gcloud, gsutil, terraform, helm v3, etc

### 2. git pre-hooks

```
repos:
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: v2.5.0
  hooks:
  - id: end-of-file-fixer
  - id: trailing-whitespace
  - id: check-added-large-files

- repo: https://github.com/jumanjihouse/pre-commit-hooks
  rev: 2.0.0
  hooks:
  - id: markdownlint

- repo: https://github.com/kintoandar/pre-commit
  rev: v2.1.0
  hooks:
  - id: prometheus_check_rules
  - id: prometheus_check_config
```  

### 3. slack integration (gitlab & prometheus)

<https://devops-team-otus.slack.com/services/B0126HVC6SJ?added=1>

в gitlab
settings -> integrations -> slack

в slack
`/github subscribe mbrbug/otus-project`

### 4. Terraform  

инициализируем конфиг terraform  
`terraform init`  
создаем конфиг terraform/main.tf
в конфигурации указан service account key
создается 1 node pool с 2 nodes

при создании кластера используется service account json файл

```
provider "google" {
  project = var.project
  region  = "us-central1"
  credentials = file("~/gcp_keys/owner-notional-portal-276509-25a6c8003fc1.json")
}
```

Поднимаем кластер в Google Cloud  
`terraform apply`  

Структура папки проекта следующая

```
├── cadvisor
│   └── templates
├── grafana
│   ├── ci
│   ├── dashboards
│   └── templates
│       └── tests
├── nginx-ingress
│   ├── ci
│   └── templates
│       └── admission-webhooks
│           └── job-patch
├── prometheus
│   ├── charts
│   │   └── kube-state-metrics
│   │       └── templates
│   └── templates
├── stackdriver-exporter
│   └── templates
├── terraform
└── terraform-helm
```

### 5. Все сервисы мониторинга и логгинга запускаются через terraform из локальных chart соответствующего сервиса

В конфигурации terraform указаны: prometheus, stackdriver-exporter, grafana, efk stack

после того как terraform создал кластер в GCP нужно установить контекст
'gcloud container clusters get-credentials my-gke-cluster --zone us-central1-c --project docker-270618'
и создать service account для дальнейшего использования при создании secret
`kubectl create secret generic stackdriver-exporter-secret --from-file=credentials.json=docker-270618-owner.json -n monitoring`

пример конфигурации terraform-helm:

```
provider "helm" {
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
...
```

### 5. Gitlab_CI

upd: Gitlab перемещен на Gitlab.com из-за прожорливости и возможного израсходования средств на тестовом GCP

скачиваем gitlab chart
helm fetch gitlab/gitlab
в values.yml
проверяем, что установится community edition  
  `edition ce`  
прописываем домен, после получения ip добавляем в dns как gitlab, minio, registry.  
  `domain: homembr.ru`  
не устанавливаем вместе с gitlab prometheus

```
  prometheus:
      install: false
```  

запуск gitlab  
`helm install gitlab -f values.yaml --set certmanager-issuer.email=am@homembr.ru ./`  

выясняем пароль root  
`kubectl get secret gitlab-gitlab-initial-root-password  -ojsonpath='{.data.password}' | base64 --decode ; echo`  

В gitlab добавлены variables

- CI_REGISTRY_USER (пользователь dockerhub)
- CI_REGISTRY_PASSWORD (пароль от dockerhub)
- GKE_SERVICE_ACCOUNT (base64 encoded file google service account json для подключения к кластеру)

дальнейший деплой приложения осуществляется через команды:

```
     - mkdir -p /etc/deploy
     - echo ${GKE_SERVICE_ACCOUNT} | base64 -d > /etc/deploy/sa.json
     - gcloud auth activate-service-account --key-file /etc/deploy/sa.json --project=${GKE_PROJECT}
     - gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --zone ${GKE_ZONE} --project ${GKE_PROJECT}
     - git clone "$CI_REPOSITORY_URL"
     - helm upgrade --install...

```

Добавлен kubernetes cluster в настройках группы

при деплое приложения используется helm3 и образ devth/helm

### 6. nginx-ingress  

используемый репозиторий helm: stable/nginx-ingress
namespace: nginx-ingress

Установка nginx-ingress без изменений из репозитория

### 7. Prometheus  

используемый репозиторий helm: stable/prometheus
namespace: monitoring

проверяем, что в values.yaml включен alertmanager и node-exporter  
проверяем, что включен ingress
и проставляем адрес prom.homembr.ru

изменен 'scrape_interval:' на 30s

Slack integration:
Добавляем блок 'alertmanagerFiles:', предварительно создав webhook в slack

```
alertmanagerFiles:
  alertmanager.yml:
    #global: {}
    global:
      slack_api_url: 'xxx_https://hooks.slack.com/services/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'
      # slack_api_url: ''

    receivers:
      - name: default-receiver
        slack_configs:
        - channel: '#andrei_maiboroda'
        #    send_resolved: true

    route:
      group_wait: 10s
      group_interval: 5m
      receiver: default-receiver
      repeat_interval: 3h
```

Добавляем в блок 'serverFiles:' правила  для мониторинга  
Следующим правилом мониторим доступность сервиса frontend в namespace production

```
   groups:
      - name: Instances
        rules:
          - alert: Prodution frontend
            expr: up{app="frontend",kubernetes_namespace="production",instance=~".*:9090"} == 0
            for: 5m
            labels:
              severity: page
            annotations:
              description: '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.'
              summary: 'Instance {{ $labels.instance }} down'
```

Добавляем в блок 'scrape_configs:' job service discovery для мониторинга сервисов приложения  
в данном примере оставляем endpoint только из namespace review  
добавляем к меткам метку kubernetes_namespace со значением namespace  
добавляем метку вида 'app=frontend'  

```
      - job_name: 'review-endpoints'
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace]
            action: keep
            regex: review
          - source_labels: [__meta_kubernetes_namespace] # Добавить namespace к меткам
            target_label: kubernetes_namespace
          - action: labelmap # Добавить название сервиса к меткам
            regex: __meta_kubernetes_pod_label_(.+)
```

в данном job оставляем endpoint  
с меткой __meta_kubernetes_pod_label_app_kubernetes_io_name равной ingress-nginx  
с меткой __meta_kubernetes_pod_container_port_number равной 10254  
и добавляем метки из группы __meta_kubernetes_service_label_app_  

```
      - job_name: 'ingress-nginx-endpoints'
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
         - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
           action: keep
           regex: ingress-nginx
         - source_labels: [__meta_kubernetes_pod_container_port_number]
           action: keep
           regex: 10254
         - action: labelmap # Добавить название сервиса к меткам
           regex: __meta_kubernetes_service_label_app_(.+)
```

и статичный сервис

```
      - job_name: 'stackdriver-exporter'
        static_configs:
          - targets:
            - 'stackdriver-exporter:9255'
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace] # Добавить namespace к меткам
            target_label: kubernetes_namespace
```

### 8. stackdriver-exporter

используемый репозиторий helm: stable/stackdriver-exporter  
namespace: monitoring

переменными через файл конфигурации terraform передаются требуемые chart'ом значения:  
gcp project и gcp service account secret, созданный ранее в этой же конфигурации terraform

### 9. Grafana  

используемый репозиторий helm: stable/stackdriver-exporter  
namespace: monitoring

в конфигурации:
включен ingress  
указан host: grafana.homembr.ru  
включен persistence  
указан размер pvc  

пароль admin выясняем из secret grafana  
`kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo`

Добавлен prometheus как datasource через кофигурационный файл values.yaml

```
datasources:
 datasources.yaml:
   apiVersion: 1
   datasources:
   - name: Prometheus
     type: prometheus
     url: http://prometheus-server
     access: proxy
     isDefault: true
```

Добавлен stackdriver как datasource через web-ui с импортом gcp service account json с правами monitoring view

Создан dashboard для мониторинга метрик сервиса frontend

variable: namespace /(production|staging|review)/

latency(95 percentile): histogram_quantile(0.95, sum(rate(opencensus_io_http_server_latency_bucket{kubernetes_namespace=~"$namespace"}[5m])) by (le))
request count by method: rate(opencensus_io_http_server_request_count_by_method{app="frontend",kubernetes_namespace=~"$namespace"}[5m])
response count by status 404 or 500: rate(opencensus_io_http_server_response_count_by_status_code{app="frontend",kubernetes_namespace=~"$namespace",http_status=~"^[45].*"}[5m])
response count by status 200 or 302: rate(opencensus_io_http_server_response_count_by_status_code{app="frontend",kubernetes_namespace=~"$namespace",http_status=~"200|302"}[5m])
etc...

Добавлены dashboards в папку dashboards локального chart 
они же добалены в конфиг

```
dashboards:
  default:
#   #   some-dashboard:
#   #     json: |
#   #       $RAW_JSON
    nginx-ingress:
      file: dashboards/nginx-ingress.json
    kuber-deployment-metrics:
      file: dashboards/kubernetes-deployment-metrics.json
    kuber-cluster:
      file: dashboards/kubernetes-cluster.json
    kuber-cluster-mon:
      file: dashboards/kuber-cluster-mon.json
    frontend-ui:
      file: dashboards/frontend-ui.json
```

### 10. EFK Stack  

используется chart <https://github.com/komljen/helm-charts/tree/master/efk> 
namespace: logging

`helm repo add akomljen-charts https://raw.githubusercontent.com/komljen/helm-charts/master/charts/`  
`kubectl create namespace logging`  
`helm install es-operator --namespace logging akomljen-charts/elasticsearch-operator`  
`cd efk`  
`helm install efk --namespace logging ./`
