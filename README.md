# Otus DevOps project

На данный момент все установлено в базовом варианте, для проверки общей работоспособности, взаимодействия сервисов и т.д.

За основу взят Hipster Shop: Cloud-Native Microservices Demo Application от Google  
Установлены gitlab, prometheus, grafana, elastiksearch, fluent-bit, kibana  
настроены pipeline для создания новых образов микросервисов, их проверки в namespace review  
а также выкатки приложения в namespace staging и production

видео
<https://youtu.be/EzFXsRzpmH0>

Репозиторий проекта
https://github.com/mbrbug/otus-project

Список публичных repo в gitlab  
<https://gitlab.homembr.ru/andrewmbr/shop-deploy>  
<https://gitlab.homembr.ru/andrewmbr/shippingservice>  
<https://gitlab.homembr.ru/andrewmbr/redis-cart>  
<https://gitlab.homembr.ru/andrewmbr/recommendationservice>  
<https://gitlab.homembr.ru/andrewmbr/productcatalogservice>  
<https://gitlab.homembr.ru/andrewmbr/paymentservice>  
<https://gitlab.homembr.ru/andrewmbr/loadgenerator>  
<https://gitlab.homembr.ru/andrewmbr/frontend>  
<https://gitlab.homembr.ru/andrewmbr/emailservice>  
<https://gitlab.homembr.ru/andrewmbr/currencyservice>  
<https://gitlab.homembr.ru/andrewmbr/checkoutservice>  
<https://gitlab.homembr.ru/andrewmbr/cartservice>  
<https://gitlab.homembr.ru/andrewmbr/adservice>  

1 Устанавливаем, если нет локально, gcloud, gsutil, terraform, helm v3, etc

2 git pre-hooks

3 slack integration (gitlab & prometheus (not yet))
<https://devops-team-otus.slack.com/services/B0126HVC6SJ?added=1>

2 Terraform  
инициализируем конфиг terraform  
`terraform init`  
создаем конфиг main.tf
Поднимаем кластер в Google Cloud  
`terraform apply`  

3 Gitlab_CI  
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

при деплое приложения используется helm3 и образ devth/helm c установленным helm3

4 nginx-ingress  
Установка nginx-ingress без изменений в конфиг из репозитория  
`helm install nginx stable/nginx-ingress`  

5 Prometheus  
проверяем, что в values.yaml включен alertmanager и node-exporter  
`helm install prom -f values.yaml ./`  

6 Grafana  
Установка grafana из репозитория

```
helm upgrade --install grafana stable/grafana --set "adminPassword=admin" \
--set "service.type=NodePort" \
--set "ingress.enabled=true" \
--set "ingress.hosts={grafana.homembr.ru}" \
--set persistence.enabled=true \
--set persistence.accessModes={ReadWriteOnce} \
--set persistence.size=8Gi -n grafana \
--namespace monitoring
```  

7 EFK Stack  
используется chart <https://github.com/komljen/helm-charts/tree/master/efk>  
`helm repo add akomljen-charts https://raw.githubusercontent.com/komljen/helm-charts/master/charts/`  
`kubectl create namespace logging`  
`helm install es-operator --namespace logging akomljen-charts/elasticsearch-operator`  
`cd efk`  
`helm install efk --namespace logging ./`
