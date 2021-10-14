Repo original assignment: https://github.com/greyhats13/contohlapak

Repo kubernetes improvisation: https://github.com/greyhats13/lapak-api-contohlapak

Repo Lapak infra: https://github.com/greyhats13/lapak-do-infra

## Answers
Everything is automated using bash.sh
Contohlapak is open on port 9090 with MySQL Redis and LoadBalanced Enabled using nginx
and the IP address 35.197.146.80 is pointed to contohlapak.blast.co.id.
You can access the endpoint using https://contohlapak.blast.co.id/db or K8s version: https://contohlapak.api.dev.blast.co.id/db
without using port because it is proxied using Nginx

Jenkins access:
https://jenkins.blast.co.id/ user:admin pass:admin123

## Bash Script
```bash
#!/bin/sh
sudo apt-get update
git pull
#Install docker on ubuntu
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg -y
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get -y install docker-ce docker-ce-cli containerd.io
#Install docker-compose
sudo apt-get -y install docker-compose
#disable docker-compose
sudo docker-compose down
#run docker compose
# sudo docker build -t greyhats13/contohlapak:latest . --no-cache
sudo docker-compose build --no-cache
sudo docker-compose up -d
sudo docker exec -i mysql mysql -uroot -ppass < tables.sql
#For generating certificate before add server listen 443
# sudo docker-compose run --rm  certbot certonly --webroot --webroot-path /var/www/certbot/ --dry-run -d contohlapak.blast.co.id
```

##Docker Compose
Here is the yaml file using version: 3.1. Docker compose will run 7 containers.
```yaml
version: '3.1'

services:
  mysql:
    container_name: mysql
    restart: always
    image: mysql
    volumes:
      - mysql_data:/var/lib/mysql
    restart: always
    ports:
      - 3306:3306
    networks:
      - contohlapak_network
    environment:
      MYSQL_DATABASE: contohlapak
      MYSQL_ROOT_PASSWORD: pass
  redis:
    container_name: redis
    image: redis
    restart: always
    ports:
      - 6379:6379
    networks:
      - contohlapak_network
  phpmyadmin:
    container_name: phpmyadmin
    restart: always
    image: phpmyadmin/phpmyadmin
    ports:
      - "8081:80"
    networks:
      - contohlapak_network
    depends_on:
      - mysql
    environment:
      PMA_HOST: mysql
      PMA_PORT: 3306
      PMA_USER: root
      PMA_PASSWORD: pass
  contohlapak:
    container_name: contohlapak
    restart: always
    # image: greyhats13/contohlapak:latest
    build:
      dockerfile: Dockerfile
      context: .
    # ports:
    #   - 9090:9090
    networks:
      - contohlapak_network
    environment:
      - MYSQL_ENABLED=true
      - REDIS_ENABLED=true
      - LOAD_BALANCED=true
      - LISTEN_PORT=9090
      - MYSQL_ADDR=mysql:3306
      - MYSQL_USER=root
      - MYSQL_PASS=pass
      - MYSQL_ROOT_PASSWORD=pass
      - MYSQL_DB=contohlapak
      - REDIS_ADDR=redis:6379
      # - HEADER_AUTH_KEY=X-CONTOHLAPAK-AUTH
    depends_on:
      - mysql
      - redis
      - phpmyadmin
  nginx:
    container_name: nginx
    image: nginx:latest
    # build:
    #   dockerfile: Dockerfile-nginx
    #   context: .
    networks:
      - contohlapak_network
    ports:
      - 80:80
      - 443:443
    restart: always
    volumes:
      - ./nginx/conf/:/etc/nginx/conf.d/:ro
      - ./certbot/www:/var/www/certbot/:ro
      - ./certbot/conf/:/etc/nginx/ssl/:ro
    depends_on: 
      - contohlapak
  certbot:
    container_name: cerbot
    image: certbot/certbot
    networks:
      - contohlapak_network
    volumes:
      - ./certbot/www/:/var/www/certbot/:rw
      - ./certbot/conf/:/etc/letsencrypt/:rw
networks:
  contohlapak_network:
    driver: bridge
volumes:
  mysql_data:
    driver: local
```
All the containers is communicating using contohlapak_networks
* Mysql container run port 3306
* MySQL is using volume mysql_data:/var/lib/mysql to make the data inside MyQL to be persistent
* Redis running in port 6379
* PhpMyAdmin running in port 8081, must be accessed without https in port 8081 http://contohlapak.blast.co.id:8081
* Contohlapak is running in port 9090 but have been proxied using https with Nginx
* Contohlapak is using environment variables from docker-compose
* Contohlapak is depend on mysql and redis container
* Contohlapak images is build using Dockerfile
```Dockerfile
FROM golang:buster

RUN mkdir /app
WORKDIR /app
COPY contohlapak .

EXPOSE 9090

ENTRYPOINT ["/app/contohlapak"]
```
The dockerfile is quite simple from golang Linux amd64 architecture. It was simple because we build the images from Golang binary.

* Nginx is running in port 80 and 443.
* Nginx as load balancing will redirect http to https
* Nginx using certificate that is generated by Certbot
* Nginx is using default.conf that will be copied to /etc/nginx/conf.d/ with read only mode

* Certbot is the container that will generate SSL certificate for contohlapak.blast.co.id
* THe certificate will be stored in certbot directory.
* After certificate is issue, then I added the server listener for 443 in Nginx and proxypass to http://contohlapak:9090


# References:
1. Terraform : https://github.com/greyhats13/lapak-do-infra
2. Sample service deployment with Dockerfile, Jenkinsfile, and Helm from public Repo:
- https://github.com/greyhats13/lapak-do-infra 

# Bukalapak Terraform : Everything as a Code
Terraform is no longer limited to Infrasructure as a Code. Thanks to provider ecosystem.


Terraform Deployment is consist of 3 deployment type:
- Cloud deployment: to provision resource on the cloud using Terraform DigitalOcean Provider such as K8s cluster, VPC, Digital Ocean project.
```terraform
provider "digitalocean" {
  token = var.do_token
}

data "terraform_remote_state" "project" {
  backend = "s3"
  config = {
    bucket  = "greyhats13-tfstate"
    key     = "${var.unit}-project-${var.env}.tfstate"
    region  = "ap-southeast-1"
    profile = "${var.unit}-${var.env}"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket  = "greyhats13-tfstate"
    key     = "${var.unit}-vpc-network-${var.env}.tfstate"
    region  = "ap-southeast-1"
    profile = "${var.unit}-${var.env}"
  }
}

#assign k8s cluster to project
resource "digitalocean_project_resources" "project_resource" {
  project = data.terraform_remote_state.project.outputs.do_project_id
  resources = [
    digitalocean_kubernetes_cluster.cluster.urn
  ]
}

data "digitalocean_kubernetes_versions" "versions" {
  version_prefix = var.version_prefix
}

resource "digitalocean_kubernetes_cluster" "cluster" {
  name    = "${var.unit}-${var.code}-${var.feature[0]}-${var.env}"
  region  = var.region
  version = data.digitalocean_kubernetes_versions.versions.latest_version

  node_pool {
    name       = "${var.unit}-${var.code}-${var.feature[1]}-${var.env}"
    size       = var.node_type
    auto_scale = var.auto_scale
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
    labels     = var.node_labels
    dynamic "taint" {
      for_each = length(var.node_taint) > 0 ? var.node_taint : {}
      content {
        key    = taint.value["key"]
        value  = taint.value["value"]
        effect = taint.value["effect"]
      }
    }
  }
  tags     = [var.unit, var.code, var.feature[0], var.env]
  vpc_uuid = data.terraform_remote_state.vpc.outputs.do_vpc_id
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}
```
- Toolchain deployment: to deploy required tools for services using Terraform Helm Provider such as Ingress-nginx, jenkins, cert-manager, and metrics server.

- Database deployment: mysql and redis deployment using Terraform Helm provider and deployed to Kubernetes cluster as Statefulsets.

Sample Helm Deployment for Redis:

Helm Module:
```terraform
data "terraform_remote_state" "k8s" {
  backend = "s3"
  config = {
    bucket  = "greyhats13-tfstate"
    key     = "${var.unit}-k8s-cluster-${var.env}.tfstate"
    region  = "ap-southeast-1"
    profile = "${var.unit}-${var.env}"
  }
}

provider "helm" {
  kubernetes {
    host  = data.terraform_remote_state.k8s.outputs.do_k8s_endpoint
    token = data.terraform_remote_state.k8s.outputs.do_k8s_kubeconfig0.token
    cluster_ca_certificate = base64decode(
      data.terraform_remote_state.k8s.outputs.do_k8s_kubeconfig0.cluster_ca_certificate
    )
  }
}

resource "helm_release" "helm" {
  name       = !var.no_env ? "${var.unit}-${var.code}-${var.feature}-${var.env}":"${var.unit}-${var.code}-${var.feature}"
  repository = var.repository
  chart      = var.chart
  values     = length(var.values) > 0 ? var.values : []
  namespace  = var.override_namespace != null ? var.override_namespace: (
    var.env == "prd" ? "Bukalapak":var.env
  )
  lint       = true
  dynamic "set" {
    for_each = length(var.helm_sets) > 0 ? {
      for helm_key, helm_set in var.helm_sets : helm_key => helm_set
    } : {}
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
}
```
Sample Redis Root Module:
```terraform
variable "redis_secrets" {
  type = map(string)
  #value is assign on tfvars
  sensitive = true
}

module "helm" {
  source     = "../../modules/helm"
  region     = "sgp1"
  env        = "dev"
  unit       = "lapak"
  code       = "database"
  feature    = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  values     = []
  helm_sets = [
    {
      name  = "auth.rootPassword"
      value = var.redis_secrets["redisPassword"]
    },
    {
      name  = "replica.replicaCount"
      value = "2"
    },
    {
      name  = "primary.persistence.size"
      value = "2Gi"
    },
    {
      name  = "secondary.persistence.size"
      value = "2Gi"
    },
        {
      name  = "master.nodeSelector.service"
      value = "backend"
    },
    {
      name  = "replica.nodeSelector.service"
      value = "backend"
    }
  ]
  override_namespace = "database"
  no_env             = true
}
```
- Service deployment: to provision github, jenkins job, and cloudflare for CI/CD for service deployment in one flows:
Module
```terraform
resource "github_repository" "repository" {
  count       = var.env == "dev" ? 1 : 0
  name        = "${var.unit}-${var.code}-${var.feature}"
  description = "Repository for ${var.unit}-${var.code}-${var.feature} service"
  visibility  = "public"
  auto_init   = "true"
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      etag
    ]
  }
}

resource "github_repository_webhook" "webhook" {
  repository = var.env == "dev" ? github_repository.repository[0].name : "${var.unit}-${var.code}-${var.feature}"

  configuration {
    url          = "https://${data.terraform_remote_state.jenkins.outputs.jenkins_cloudflare_endpoint}/multibranch-webhook-trigger/invoke?token=${var.unit}-${var.code}-${var.feature}-${var.env}"
    content_type = "json"
    insecure_ssl = false
  }

  active = true

  events = ["push"]
  depends_on = [
    github_repository.repository
  ]
}

resource "jenkins_job" "job" {
  name     = "${var.unit}-${var.code}-${var.feature}-${var.env}"
  folder   = jenkins_folder.folder.id
  template = file("${path.module}/job.xml")

  parameters = {
    description       = "Job for ${var.unit}-${var.code}-${var.feature}-${var.env}"
    unit              = var.unit
    code              = var.code
    feature           = var.feature
    env               = var.env
    credentials_id    = var.credentials_id[0]
    github_username   = var.github_username
    github_repository = var.github_repository
  }
}
```

Root Module:
```terraform
module "cloudflare" {
  source             = "../../modules/cloudflare"
  env                = var.env
  unit               = var.unit
  code               = var.code
  feature            = var.feature
  cloudflare_secrets = var.cloudflare_secrets
  zone_id            = var.cloudflare_secrets["zone_id"]
  type               = var.type
  ttl                = var.ttl
  proxied            = var.proxied
  allow_overwrite    = var.allow_overwrite
}

module "github" {
  source         = "../../modules/github"
  env            = var.env
  unit           = var.unit
  code           = var.code
  feature        = var.feature
  github_secrets = var.github_secrets
}

module "jenkins" {
  source            = "../../modules/jenkins"
  env               = var.env
  unit              = var.unit
  code              = var.code
  feature           = var.feature
  jenkins_secrets   = var.jenkins_secrets
  github_username   = var.github_secrets["owner"]
  github_repository = module.github.github_repository
  credentials_id    = var.credentials_id
}
```


# Bukalapak CI/CD:
After All cloud resources, toolchain, database(MySQL, REdis), and CI/CD is setup by Terraform. The CI/CD is using Feature Branch workflow. 
- Push event will trigger dev pipeline
- Pull request to Main(master) will trigger Staging pipeline
- Release tag will trigger production pipeline.
It is not 100% implemented due to limited times. So, most of the versioning strategy is a part of feature branch formality.

CI/CD is setup as pipeline as a code in Jenkinsfile. It contains three stages:
1. Source(Checkout)
If delivery team perform push event, the webhook will trigger pipeline.
Jenkins will pull the current push and start to build.
```bash
def scm = checkout([$class: 'GitSCM', branches: [[name: runBranch]], userRemoteConfigs: [[credentialsId: 'gitlab-auth-token', url: repo_url]]])
```
2. Build
Jenkins will build the services as docker container. Jenkins will build the container based what is defined on Dockerfile.
Sample Golang Dockerfile:
```dockerfile
FROM golang:1.15.2-alpine3.12 AS builder

RUN apk update && apk add --no-cache git

WORKDIR $GOPATH/src/lapak-core-test/

COPY . .

RUN GOOS=linux GOARCH=amd64 go build -o /go/bin/lapak-core-test

FROM alpine:3.12

RUN apk add --no-cache tzdata

COPY --from=builder /go/bin/lapak-core-test /go/bin/lapak-core-test

ENTRYPOINT ["/go/bin/lapak-core-test"]
```
Sample Python Dockerfile:
```Dockerfile
FROM python:3.4-alpine
RUN apk add --no-cache bash
COPY . /app
WORKDIR /app
RUN pip3 install -r requirements.txt
EXPOSE 5000
RUN chmod +x docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0"]
```
Jenkins build imlementation:
```bash
def dockerBuild(Map args) {
    sh "docker build -t ${args.docker_username}/${args.service_name}:${args.build_number} ."
}
```
3. Push and Tagging to Hub Docker registry
After build the docker images, Jenkins will login to Dockerhub.
```bash
docker.withRegistry("", docker_creds) {
    dockerPush(docker_username: docker_username, service_name: service_name, build_number: build_number)

    dockerPushTag(docker_username: docker_username, service_name: service_name, build_number: build_number, version: version)
  }
}

```
Thus, Jenkins will tagging the docker images based on version (determined) by the environment, and eventually push then to Hub Docker registry.
```bash
def dockerPush(Map args) {
    sh "docker push ${args.docker_username}/${args.service_name}:${args.build_number}"
}

def dockerPushTag(Map args) {
    sh "docker tag ${args.docker_username}/${args.service_name}:${args.build_number} ${args.docker_username}/${args.service_name}:${args.version}"
    sh "docker push ${args.docker_username}/${args.service_name}:${args.version}"
}
```
I have implemented versioning for docker. For development will have alpha version and the tag of build version. Staging will be assigned with beta version tag, and production will be assigned with latest version and release tag.

4. Helm Deployment
After push the docker images to Hub Docker, Jenkins will initiate helm deployment. Helm files is given name based on their development such as values-dev.yaml, values-stg.yaml, and values.yaml(prd). Helm deployment consist of three steps which is.
a. To verifiy whether helm chart is in well formed
```bash
sh "helm lint -f ${helm_values}"
```
b. It will performed debugging check without having to really install the helm to the K8s cluster;
```bash
sh "helm -n ${namespace} install ${service_name} -f ${helm_values} . --dry-run --debug"
```
c. After all the check, we performed the Helm deployment.
```bash
sh "helm -n ${namespace} upgrade --install ${service_name} -f ${helm_values} . --recreate-pods"
```

# Helm Charts for Services, Ingress, SSL
Helm chart really make our life easier. We didn't have to perform
```bash
helm upgrade --install -f values.yaml . -n <namespace>
```
manually. All the kubernetes deployment in this assigment is performed using Helm chart and many of them is performed using Terraform or Jenkins CI/CD.
1. Service Deployment (microservices)
For this technical test, I have customized the helm chart for service deployment, services,  from 
```bash 
helm create sampleservice
```
and add configmap and secrets to the helm templates then associated them with environment variable on deployment (envFrom).
```yaml
replicaCount: 1
podAnnotations:
  prometheus.io/scrape: "false"
image:
  repository: greyhats13/lapak-api-contohlapak:alpha
  pullPolicy: Always
nameOverride: ""
fullnameOverride: ""
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
appConfigMap:
  DB_HOST: lapak-database-mysql.database.svc.cluster.local:3306
  DB_DATABASE: Bukalapak_db
  DB_USERNAME: root
  FLASK_APP: server.py
  FLASK_ENV: development
  JWT_SECRET: 12345
  UPLOAD_FOLDER: upload
appSecret:
  DB_PASSWORD: admin123
```
2. Ingress-Nginx
I exposed my sample services to the internet using Ingress Nginx. Ingress Nginx is using DO load balancer. All of the services ingress is assigned to Nginx ingress class on the annotation, and exposed their services to the internet.

3. SSL/TLS
My sample services ingres also using TLS/SSL from LetsEncrypt cert-maanger by assigning the cluster issuer on the ingress annotation.

```yaml
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    cert-manager.io/cluster-issuer: letsencrypt-lapak
    ingressClassName: nginx
  hosts:
    - host: api.core.dev.blast.co.id
      paths: []
  tls:
    - secretName: lapak-api-contohlapak-dev-ssl
      hosts:
        - api.core.dev.blast.co.id
```
4. Enable Horizontal Pod Autoscaler for service scalability and elasticity
```yaml
autoscaller:
  replicas:
    min: 2
    max: 20
  utilization:
    cpu: 75
    memory: 75
```

5. Helm chart for deploying Redis and MySQL as Stateful Sets.
Most of data layer deployment need persistency such as Redis, MySQL, MongoDB, Elasticsearch (ECK). I deployed Redis as stateful sets to the kubernetes cluster.


## Overview
Contohlapak is a simple Go application that, when run, serves a web server at
port 80. Its behavior can be modified by supplying environment variables or by
running it on the same folder as a `.env` file.

### Basic Endpoints
All responses from the application is JSON.
* `GET /healthz` will return a simple 200 OK if the application is running.
* `GET /metrics` will return a prometheus metrics page.

### MySQL Endpoints
* `GET /db` will return all entries in the `lapak` table.
* `POST /db` will insert an entry to the `lapak` table given a JSON request body
   with the following schema:
   ```json
   {
     "name": "lapak01",
     "owner": "budi",
     "products_sold": 10
   }
   ```

### Redis Endpoints
* `GET /cache` will retrieve the value of a stored key. The `key` attribute is
   required.
* `GET /cache/list` will retrieve all keys in the cache.
* `POST /cache` will store a new key-value pair into the cache. The `key` and
  `value` attribute is required.

## Configuration
All configuration is done via environment variables, which can be supplied 
normally or by placing an `.env` file in the folder where the application is
located (see `.env.sample` file given for example). 

### Basic
* `LISTEN_PORT` changes the port which the application will listen in for
  requests. Defaults to 8080 if not specified.

### Feature Toggles
The application currently supports three features that can be enabled or disabled
by setting specific environment variables:
* MySQL (`MYSQL_ENABLED`)
* Redis (`REDIS_ENABLED`)
* Load Balancing (`LOAD_BALANCED`)

In order to enable the feature, the value of those variables must be set to `true`.

### Redis-specific
* `REDIS_ADDRESS` defines the redis address which the application will connect
  to.

### MySQL-specific
* `MYSQL_ADDRESS` defines the address of the mysql instance
* `MYSQL_USER` defines the username used to authenticate into the mysql instance
* `MYSQL_PASS` defines the password used to authenticate into the mysql instance
* `MYSQL_DB` defines the name of the database the application will connect to.
  **The database schema needs to be initialized manually.**
* MySQL Schema:
  ```mysql
  CREATE TABLE IF NOT EXISTS lapak (
    id INT NOT NULL AUTO_INCREMENT,
    PRIMARY KEY(id),
    lapak_name VARCHAR(256) NOT NULL,
    lapak_owner VARCHAR(256) NOT NULL,
    products_sold INT NOT NULL
  ); 
  ```
## Build Instructions
* You need Go installed to compile the program. It can be downloaded here:
  ```https://golang.org/dl/```
* The program can then be compiled by running the following command:
  ```
   GOOS=linux GOARCH=amd64 go build -o contohlapak app/main.go
  ```
* An executable should appear on the current directory, it can then be run:
  ```
  ./contohlapak
  ```
