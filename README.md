# Otus DevOps project

На данный момент все установлено в базовом варианте, для проверки общей работоспособности, взаимодействия сервисов и т.д.

За основу взят Hipster Shop: Cloud-Native Microservices Demo Application от Google  
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
в slack
`/github subscribe mbrbug/otus-project`

в gitlab
settings -> integrations -> slack

2 Terraform  
инициализируем конфиг terraform  
`terraform init`  
создаем конфиг main.tf
Поднимаем кластер в Google Cloud  
`terraform apply`  

3 Gitlab_CI

upd: Gitlab перемещен на Gitlab.com из-за прожорливости и возможного израсходования средств на GCP

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

при деплое приложения используется helm3 и образ devth/helm c установленным helm3

4 nginx-ingress  
Установка nginx-ingress без изменений в конфиг из репозитория  
`helm install nginx stable/nginx-ingress`  

5 Prometheus  namespace: monitoring

проверяем, что в values.yaml включен alertmanager и node-exporter  
`helm install prom --namespace monitoring -f values.yaml ./`  

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

Добавляем в блок 'serverFiles:'  

```
   groups:
      - name: Instances
        rules:
          - alert: InstanceDown
            expr: up == 0
            for: 5m
            labels:
              severity: page
            annotations:
              description: '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.'
              summary: 'Instance {{ $labels.instance }} down'
```

6 Grafana  
Установка grafana из репозитория. namespace: monitoring

```
helm upgrade --install grafana stable/grafana --set "adminPassword=admin46" \
--set "service.type=NodePort" \
--set "ingress.enabled=true" \
--set "ingress.hosts={grafana.homembr.ru}" \
--set persistence.enabled=true \
--set persistence.accessModes={ReadWriteOnce} \
--set persistence.size=8Gi -n grafana \
--namespace monitoring
```  

Добавлен prometheus как datasource
Добавлен stackdriver как datasource

Создан dashboard для мониторинга метрик сервиса frontend
latency(95 percentile): histogram_quantile(0.95, sum(rate(opencensus_io_http_server_latency_bucket{kubernetes_namespace=~"$namespace"}[5m])) by (le))
request count by method: rate(opencensus_io_http_server_request_count_by_method{app="frontend",kubernetes_namespace=~"$namespace"}[5m])
response count by status 404 or 500: rate(opencensus_io_http_server_response_count_by_status_code{app="frontend",kubernetes_namespace=~"$namespace",http_status=~"^[45].*"}[5m])
response count by status 200 or 302: rate(opencensus_io_http_server_response_count_by_status_code{app="frontend",kubernetes_namespace=~"$namespace",http_status=~"200|302"}[5m])
etc...

7 EFK Stack  
используется chart <https://github.com/komljen/helm-charts/tree/master/efk>  
`helm repo add akomljen-charts https://raw.githubusercontent.com/komljen/helm-charts/master/charts/`  
`kubectl create namespace logging`  
`helm install es-operator --namespace logging akomljen-charts/elasticsearch-operator`  
`cd efk`  
`helm install efk --namespace logging ./`
