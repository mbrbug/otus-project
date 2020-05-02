# Otus DevOps project

На данный момент все установлено в базовом варианте, для проверки общей работоспособности, взаимодействия сервисов и т.д.

За основу взят Hipster Shop: Cloud-Native Microservices Demo Application от Google
Изменен сервис frontend:
на порту 9090 сервис отдает метрики: latency bucket, количество кодов состояния HTTP (200, 302, 404, 500), запрос по типу (GET, POST)
Удалено создание LoadBalancer при деплое. Вместо него добавлено создание nginx ingress. С адресами production, staging, review.

frontend/chart/templates/ingress.yaml
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

1 Устанавливаем, если нет локально, gcloud, gsutil, terraform, helm v3, etc

2 git pre-hooks

3 slack integration (gitlab & prometheus (not yet))
<https://devops-team-otus.slack.com/services/B0126HVC6SJ?added=1>

в gitlab
settings -> integrations -> slack

в slack
`/github subscribe mbrbug/otus-project`

2 Terraform  
инициализируем конфиг terraform  
`terraform init`  
создаем конфиг terraform/main.tf
Поднимаем кластер в Google Cloud  
`terraform apply`  

3 Все сервисы мониторинга и логгинга запусткаются через terraform из локальных chart соответствующего сервиса.

```
provider "helm" {
}

resource "helm_release" "nginx-ingress" {
  name      = "nginx-ingress"
  chart     = "../nginx-ingress"
  namespace = "nginx-ingress"
  recreate_pods = true
}
...
```

3 Gitlab_CI

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

Добавлен kubernetes cluster в настройках группы

при деплое приложения используется helm3 и образ devth/helm

4 nginx-ingress  
Установка nginx-ingress без изменений из репозитория  

5 Prometheus  namespace: monitoring

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

6 Grafana  
namespace: monitoring

в конфиге:
включен ingress
указан host: grafana.homembr.ru
включен persistence
указан размер pvc
указан adminPassword: strongpassword

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


7 EFK Stack  
используется chart <https://github.com/komljen/helm-charts/tree/master/efk>  
`helm repo add akomljen-charts https://raw.githubusercontent.com/komljen/helm-charts/master/charts/`  
`kubectl create namespace logging`  
`helm install es-operator --namespace logging akomljen-charts/elasticsearch-operator`  
`cd efk`  
`helm install efk --namespace logging ./`
