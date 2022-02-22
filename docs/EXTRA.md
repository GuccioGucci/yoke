# Extra

* [Deployment Controllers](#deployment-controllers)
  * [ECS: Rolling Update](#ecs-rolling-update)
  * [EXTERNAL: Canary Release](#external-canary-release)
* [Lifecyle Hooks](#lifecyle-hooks)
* [Provisioning: Terraform](#provisioning-terraform)
  * [Mixed: managed and live (migrating to Update mode)](#mixed-managed-and-live-migrating-to-update-mode)
  * [Afterwards: live only (migrating to Install mode)](#afterwards-live-only-migrating-to-install-mode)
  * [Bootstrap: live only, with bogus (creating from scratch)](#bootstrap-live-only-with-bogus-creating-from-scratch)
* [Templates](#templates)
  * [Deployment](#deployment)
  * [Pipelines: Jenkins](#pipelines-jenkins)
* [Application configuration override](#application-configuration-override)
  * [Ktor and Jib](#ktor-and-jib)
  * [Spring Boot and Dockerfile](#spring-boot-and-dockerfile)
  * [ReactJS](#reactjs)

# Deployment Controllers

AWS ECS services can be configured to be provisioned with specific [deployment controller](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_DeploymentController.html). By default, it would be `ECS` (fully managed deployments). Alternatively, you can configure `CODE_DEPLOY` (unsupported, as it implies using AWS CodeDeploy) and `EXTERNAL` (for delegating third-party component, actually `yoke` itself).

## ECS: Rolling Update

Currently, we mainly promote using `yoke` with services provisioned as `ECS`. Both **update** and **install** modes would then rely on ECS for managing the deployments lifecycle. It would result in a [Rolling Update](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-type-ecs.html), described as:

> ... replacing the current running version of the container with the latest version. The number of containers Amazon ECS adds or removes from the service during a rolling update is controlled by adjusting the minimum and maximum number of healthy tasks allowed during a service deployment, as specified in the DeploymentConfiguration.


Here's a sample execution:

```
 ./yoke install -c cls01 -s hello-world-dev -t bb255ec-93 -w test/samples/hello-world/deployment -f values-dev.yaml
 
 (1) [2021-01-05 16:34:33] values: test/samples/hello-world/deployment/values-dev.yaml
 (2) [2021-01-05 16:34:33] task-definition: test/samples/hello-world/deployment/task-definition.json.tmpl
 (3) [2021-01-05 16:34:33] (current) task-definition: /tmp/task-definition.json.17213
 (4) Deployment controller: ECS
 (5) Using image name: bb255ec-93
 (6) Current task definition: arn:aws:ecs:us-east-1:1234567890:task-definition/hello-world-dev:10
 (7) New task definition: arn:aws:ecs:us-east-1:1234567890:task-definition/hello-world-dev:11
 (8) .......
 (9) Service updated successfully, new task definition running.
(10) Waiting 300s for service deployment to complete...
(11) ..............................................
(12) Service deployment successful.
```

By default, it will:

* create new fully-sized deployment (`7`-`9`)
* wait for new deployment to be steady (`10`-`12`)

Once `yoke` execution is completed, ECS is still disposing previous deployment, which is no more load-balanced (and so, safely disposable).

## EXTERNAL: Canary Release

Experimental support for `EXTERNAL` deployment controller is in progress, supporting [Canary Release](https://martinfowler.com/bliki/CanaryRelease.html). This requires `yoke` to manage not only task definitions, but also task sets (actually, *managed* deployments). Once remote service is detected to be configured as `EXTERNAL`, both **update** and **install** modes would then manage the deployment lifecycle, enriching `ecs-deploy` command line to do so (see [contributions](#contributions) section for details and [deployment.bats](/test/unit/deployment.bats) for sample usages).

For **install** mode only, in addition to `task-definition.json.tmpl`, you can provide a `task-set.json.tmpl` file as well, again expected to be found in the working directory, eg:

```
deployment/
├── task-definition.json.tmpl
├── task-set.json.tmpl
└── values-dev.yaml
```

Expected `task-set.json.tmpl` content is a JSON file, with a `taskSet` root node matching [aws ecs update-task-set request](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ecs/update-task-set.html) JSON syntax. Here's an example:

```
{
  "taskSet": {
    "networkConfiguration": { ... },
    "loadBalancers": [ { ... } ],
    "serviceRegistries": [ ],
    "launchType": "FARGATE",
    "platformVersion": "LATEST",
    "scale": {
      "value": 100,
      "unit": "PERCENT"
    }
  }
}
```

Please, consider the impact on provisioning, once you configure `EXTERNAL` deployment controller, eg: removing resources from Terraform (see [Provisioning: Terraform](#provisioning-terraform) section).

Here's a sample execution:

```
 (1) [2021-01-05 16:38:00] values: test/samples/hello-world-x/deployment/values-dev.yaml
 (2) [2021-01-05 16:38:00] confirmation: test/samples/hello-world-x/deployment/bin/confirm.sh.tmpl
 (3) [2021-01-05 16:38:00] (current) confirmation: /tmp/confirm.sh.7947
 (4) [2021-01-05 16:38:00] task-definition: test/samples/hello-world-x/deployment/task-definition.json.tmpl
 (5) [2021-01-05 16:38:00] (current) task-definition: /tmp/task-definition.json.12699
 (6) [2021-01-05 16:38:02] task-set: test/samples/hello-world-x/deployment/task-set.json.tmpl
 (7) [2021-01-05 16:38:02] (current) task-set: /tmp/task-set.json.25561
 (8) Deployment controller: EXTERNAL
 (9) Using image name: bb255ec-93
(10) Current task definition: arn:aws:ecs:us-east-1:1234567890:task-definition/hello-world-x-dev:11
(11) New task definition: arn:aws:ecs:us-east-1:1234567890:task-definition/hello-world-x-dev:12
(12) Creating new canary deployment of the service
(13) Current deployments
(14) {"externalId":"stable-20210501-172006","status":"ACTIVE","scale":"100%","desired":4,"pending":0,"running":4}
(15) {"externalId":"canary-20210501-163811","status":"ACTIVE","scale":"25%","desired":0,"pending":0,"running":0}
(16) Waiting 300s for service deployment to complete...
(17) .................
(18) Service deployment successful.
(19) 
(20) Waiting 10s...
(21) ..........
(22) Creating new stable deployment of the service
(23) Waiting 300s for service deployment to complete...
(24) ............
(25) Service deployment successful.
(26) 
(27) Deleting previous (stable) deployment of the service
(28) Deleting canary deployment of the service
(29) Current deployments
(30) {"externalId":"stable-20210501-163909","status":"ACTIVE","scale":"100%","desired":4,"pending":0,"running":4}
(31) {"externalId":"stable-20210501-172006","status":"DRAINING","scale":"0%","desired":4,"pending":0,"running":4}
(32) {"externalId":"canary-20210501-163811","status":"DRAINING","scale":"0%","desired":1,"pending":0,"running":1}
```

At the moment, **Canary Release** strategy is the following:

* create *new canary* deployment, scaled to 25% of desired size (`11`-`15`)
* wait for *new canary* deployment to be steady (`16`-`18`)
* apply confirmation strategy, custom or default to `wait_timeout` (`20`-`21`)
* create *new stable* deployment, scaled to 100% of desired size (`22`)
* wait for *new stable* deployment to be steady (`23`-`25`)
* delete *existing stable* deployment (`27`)
* delete *new canary* deployment (`28`)

Custom **confirmation strategy** can be prepared, by defining a `confirm.sh.tmpl` script (see [confirm.sh.tmpl](/test/samples/hello-world-x/deployment/bin/confirm.sh.tmpl) as an example). Even if very basic at the moment, such provided script is intended to hold any custom logic to inspect *new canary* deployment status, and when a given confidence level is granted, confirming proceeding with *new stable* deployment.

For example, it could check within a given period (eg: next 5 minutes or so) for specific data, such as:

* application ERROR logs, with [aws logs tail](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/logs/tail.html) cli
* system or application metrics, with [aws cloudwatch get-metric-statistics](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/cloudwatch/get-metric-statistics.html) cli

The script is expected to `exit 0` while ready to proceed, and to be found in `bin` folder, under current working-dir:

```
deployment/
└── bin
    └── confirm.sh.tmpl
```

# Lifecyle Hooks

Additional actions can be performed hooking into particular lifecycle events. Again, script templates are expected to be found in `bin` folder, under current working-dir. As for canary releases script template, you can use values from value file, if set in the command line.

Currently the only supported hook is `post`, for post-deploy action:

```
deployment/
└── bin
    └── post.sh.tmpl
```

# Provisioning: Terraform

You're probably guessing what's the impact on provisioning, once we move task-definition out of Terraform scope (since task-definition in `ECS` are managed resources, with individual revisions). Here's an [interesting discussion on the topic](https://github.com/hashicorp/terraform-provider-aws/issues/632), with alternative approaches.

We'll recap them here, with examples, using the following as reference scenario: a shared `module.tf`, with common definitions, and per-environment `$stage/main.tf` files (eg: `dev/main.tf`, `qa/main.tf` and `prd/main.tf`).

## Mixed: managed and live (migrating to Update mode)

One approach is to rely on both a [`aws_ecs_task_definition`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) `resource` for *managed* task definition, and also a [`aws_ecs_task_definition`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_task_definition) `data` to get current *live* task definition in the `ECS` environment. Then, on [`aws_ecs_service`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) `resource`, you can pick the "latest" `task_definition`, being either *managed* or *live* one ("latest" meaning being the *biggest* of them).

Here's an example:

```
resource "aws_ecs_task_definition" "td" {
  family = ...
  ...
}

data "aws_ecs_task_definition" "current_td" {
  task_definition = aws_ecs_task_definition.td.family
}

resource "aws_ecs_service" "esv" {
  task_definition = "${aws_ecs_task_definition.td.family}:${max(aws_ecs_task_definition.td.revision,data.aws_ecs_task_definition.current_td.revision)}"
  ...
```

## Afterwards: live only (migrating to Install mode)

Another approach, going even further, is getting rid of `aws_ecs_task_definition` `resource` for *managed* task definition, and only relying on `aws_ecs_task_definition` `data` for *live* task definition, using it to configure `aws_ecs_service` `resource`. Of course, this can only be achieved once the task definition has already been created! So for example, that could be done to migrate an existing service, from a previously "all-managed" approach.

Here's an example:

```
data "aws_ecs_task_definition" "current_td" {
  task_definition = ...
}

resource "aws_ecs_service" "esv" {
  task_definition = "${data.aws_ecs_task_definition.current_td.family}:${data.aws_ecs_task_definition.current_td.revision}"
  ...
}
```

## Bootstrap: live only, with bogus (creating from scratch)

Even better, we could always rely on *already existing* task definitions, with a little trick: using some default "off-the-shelf" ones the very first time (on creation), then following previous solution (*live* only), afterwards.

This sounds like a ["chicken and egg" problem](https://en.wikipedia.org/wiki/Chicken_or_the_egg): having a task definition already prepared *before* the very first application deploy (which holds the actual task definition). For reference, this was inspired by [this approach](https://github.com/hashicorp/terraform-provider-aws/issues/632#issuecomment-472420686), from the previously shared discussion on the topic.

In order to do so, we need to:

* distinguish *first* and *following* `terraform apply` executions
* prepare "off-the-shelf" task definitions (referred to as `bogus`)

First goal can be achieved using a variable on command-line (e.g. `bootstrap`), being `false` by default and set `true` on first execution. Here's an example:

```
# first time
terraform apply -var bootstrap=true

# following executions
terraform apply
```

So the only change, in respect to previous example, is to pick the proper task definition family, accordingly to `bootstrap`.

* `module.tf`
```
variable "bootstrap" {}

locals {
  ...
  container_port = 8090
  task_definition_family = var.bootstrap ? "bogus-${local.container_port}" : "${local.svc_name}-${var.stage}"
}

data "aws_ecs_task_definition" "current_td" {
  task_definition = local.task_definition_family
}
```

* `$stage/main.tf`
```
variable "bootstrap" {
  default = false
}

module "main" {
  ...
  bootstrap = var.bootstrap
}
```

For achieving second goal, we prepared a [bogus Docker image](/docker/bogus), with a minimal [Nginx](https://www.nginx.com/) website, always replying with a `200 OK` response on any endpoint. This is ideal for emulating a proper health-check, as it would be for the real application.

This Docker image is expected to be built and pushed to your reference Docker registry (`ECR` or private one), and then referenced in dedicated `bogus` task definitions. Suggested approach is provisioning one task definition for every exposed HTTP port, eg: `bogus-80`, `bogus-8080`, `bogus-8090` and the like. Here's a sample Terraform snippet for doing so:

```
variable "container_ports" {
  type        = list(string)
  default     = ["80", "8080", "8090" ... ]
}

resource "aws_ecs_task_definition" "td" {
  count = length(var.container_ports)
  family = "bogus-${var.container_ports[count.index]}"
  container_definitions = <<EOF
[
    {
      "name": "application",
      "image": "$DOCKER_REGISTRY$/bogus:latest",
      "environment": [
        { 
          "name": "NGINX_PORT",
          "value": "${var.container_ports[count.index]}"
        }
      ],
      "portMappings": [
        {
            "containerPort": ${var.container_ports[count.index]}
        }
      ],
      "cpu" : 0,
      "volumesFrom": [ ],
      "mountPoints": [ ],
      "essential": true
    }
  ]
EOF
  memory = ...
  cpu = ...
  execution_role_arn = ...
  network_mode = ...
  requires_compatibilities = [
    "FARGATE",
  ]
}
```

Please, note that in order to migrate from *bogus* to *application* task definition, you have to keep the same container **name** (in addition to container port and health-check path), otherwise the the load balancer would fail to re-configure (`application` in the above example). Ensure you're using the same in `ECS` service definition:

```
resource "aws_ecs_service" "esv" {
  ...
  load_balancer {
    ...
    container_name = "application"
  }
}
```

# Templates

## Deployment

A deployment template is provided in [templates/deployment](/templates/deployment). Copy & paste it in your application sources, for example on root folder.

Sample values files should be ready to be used, while you should edit [`task-definition.json.tmpl`](/templates/deployment/task-definition.json.tmpl):

* replace `${APPLICATION}` with your application name. This is also expected to be the Docker repository image name
* replace `${CONTAINER_PORT}` with load-balanced HTTP port for your application, as in your provisioning configuration (eg: Terraform)
* replace `${SERVICE}` with your service name, in order match `${SERVICE}-{{ .environment.name }}` with your provisioning configuration (eg: Terraform)

### Pipelines: Jenkins

While integrating with [Jenkins](https://www.jenkins.io/), one possible approach is using one **main** pipeline for orchestrating build, test and deployment on all environments (`dev`, `qa` and `prd`), while delegating deployment to a dedicated **deploy** pipeline.

![Pipelines, Jenkins: main](/docs/pipelines-jenkins-main.png "Pipelines, Jenkins: main")

The **main** pipeline would build application version for a given commit (`BRANCH` parameter), while the **deploy** pipeline would be executed multiple times, deploying the very same Docker image (`TAG` parameter) on individual environments (`ENVIRONMENT` parameter). Deployment on each environment other than `dev` will be asked for confirmation (with `input` step), on `master` branch only (please, change it to match your *trunk* branch naming).

![Pipelines, Jenkins: deploy](/docs/pipelines-jenkins-deploy.png "Pipelines, Jenkins: deploy")

For doing so, sample templates are provided in [templates/pipeline](/templates/pipeline):

* [`Jenkinsfile`](/templates/pipeline/Jenkinsfile) is the **main** pipeline
  * set `APPLICATION` to your application name. This is also expected to be the Docker repository image name
  * create a Jenkins job using this `Jenkinsfile` as the pipeline
* [`Jenkinsfile.deploy`](/templates/pipeline/Jenkinsfile.deploy) is the **deploy** pipeline, interacting with `yoke` in order to deploy on `ECS`
  * set `APPLICATION` to your application name (as in previous step)
  * set `SERVICE` to your service name, in order match `${params.ENVIRONMENT}-${SERVICE}` with your Terraform configuration
  * customize any `prd`-specific tasks that you want to perform (eg: configuring AWS profiles and/or promoting images from nonprod to prod Docker registries)
  * create a Jenkins job using this `Jenkinsfile.deploy` as the pipeline, named `${APPLICATION}_deploy`

Then, in `Jenkinsfile.deploy` please consider using in a specific tag instead of relying on `main` branch, in order to keep control of `yoke` version. To do so, please set `YOKE_VERSION` to any available tag. See [CHANGELOG](/CHANGELOG.md) for details about individual versions.

# Application configuration override

Given task-definition is prepared at deploy-time, it could be used to override application configurations, with external resources. For example, you can prepare environment-specific application configuration override files, under same working-dir folder (eg: `deployment/config`):

```
deployment/
└── config/
    ├──dev/
    │  └── application-override.conf
    ├──qa/
    │  └── application-override.conf
    └──prd/
       └── application-override.conf
```

In other words, this would allow configuring the bare minimum environment variables possible (while still adhering to [12 Factor App](https://12factor.net/config) approach). For example, cleaning up `environment` node, only leaving those used by `Dockerfile` or other resources
. On the other hand, we'd preserve `secrets` node (then being injected as environment variables as well).

For doing so, we can leverage on language or framework specific techniques for injecting complete or partial application configuration files, for a given environment, at run-time. See following sections for few specific examples.

The overall approach is documented [here](https://kichik.com/2020/09/10/mounting-configuration-files-in-fargate/), and it's easily adapted from CloudFormation. In few words:

* a dedicated *ephemeral* `application-config` container is defined, with the only purpose of creating a dedicated configuration file. Configuration file's content is read from a `DATA` environment variable
* `application` container depends on `application-config` container to be `COMPLETE`, so it can then terminate once done (see [here](https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_ContainerDependency.html) for reference). This is to ensure configuration file would already be prepared, at application startup
* `DATA` environment variable into `application-config` container definition is then valued with original file content, encoded to base64 (that should preserve any special char and newlines)

Here's a draft `task-definition.json.tmpl`:

```
{{/*
  $configurationPath and $applicationConfigurationOverride are set to match Docker configuration (eg: Jib, Dockerfile or other tooling for preparing Docker images)
  please keep them in synch, would they be migrated.
*/}}
{{- $applicationConfigurationOverride := "..." -}} # eg: application-override.yaml
{{- $configurationPath := "..." -}} # eg: /app/config
{
  "taskDefinition": {
   ...
    "volumes": [
      {
        "host": { },
        "name": "application-config"
      }
    ],
    "containerDefinitions": [
      {
        "name": "application",
        ...
        "dependsOn": [
          {
            "containerName": "application-config",
            "condition": "COMPLETE"
          }
        ],
        "mountPoints": [
          {
            "containerPath": "{{ $configurationPath }}",
            "sourceVolume": "application-config"
          }
        ]
      },
      {
        "name": "application-config",
        "essential": false,
        "image": "bash",
        "command": [
          "-c",
          "echo $DATA | base64 -d - | tee {{ $configurationPath }}/{{ $applicationConfigurationOverride }}"
        ],
        "environment": [
          {
            "name": "DATA",
            "value": "{{ shell "openssl base64 -A -in config/" .environment.name "/" $applicationConfigurationOverride }}"
          }
        ],
        "mountPoints": [
          {
            "containerPath": "{{ $configurationPath }}",
            "sourceVolume": "application-config"
          }
        ]
      }
    ]
  }
}
```

## Ktor and Jib

For example, with [Ktor](https://ktor.io/) and [Jib](https://github.com/GoogleContainerTools/jib), you'd probably need:

```
{{- $applicationConfigurationOverride := "application-override.conf" -}}
{{- $configurationPath := "/app/resources/config" -}}
```

Then, you only need to enable overriding in `Ktor` application config, relying on [HOCON "include"](https://github.com/lightbend/config/blob/main/HOCON.md#includes) capability, adding this as the very last line in application.conf file:
```
include "config/application-override.conf"
```

## Spring Boot and Dockerfile

For [Spring Boot](https://spring.io/projects/spring-boot) application, you could use:

```
{{- $applicationConfigurationOverride := "application-override.properties" -}} # or application-override.yaml
{{- $configurationPath := "/opt/service/config" -}} # as configured in your Dockerfile or base Docker image
```

Then, you could use `spring.config.additional-location` property to application startup command line (eg: `Dockerfile`, `bootstrap.sh` or equivalent), as documented [here](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.external-config). So, adding this to application startup command line (eg: `Dockerfile`, `bootstrap.sh` or equivalent) would be enough:

```
java -jar service.jar ... \
     --spring.config.additional-location=config/application-override.properties # or application-override.yaml
```

Please, note that on recent versions (such as `2.5.0`), there was a breaking change, so that resource set to that property is always expected to exist (while with older version such as `2.2.5.RELEASE`, it was allowed to set a non-existing resource).

## ReactJS

For [ReactJS](https://reactjs.org/), few approaches have been proposed to achieve "build once, deploy anywhere" goal. Leveraging on application configuration override, instead of individual environment variables, is probably the easiest of the solutions (see [here](https://www.cotyhamilton.com/build-once-deploy-anywhere-for-react-applications/) for reference).

The overall idea is to:

* provide shared *default* values (to be used in most of environments), eg: `config.js` in `public` folder
* provide local *development* override values (to be used locally), eg: `config-override.js` in `public/env` folder
* provide *per-environment* override values (to be used on deployment), eg: still `config-override.js`, but in yoke working directory (eg: `deployment` folder)
* prepare global configurations in `window.config` object, by merging default and override files

So both *default* and *development* override config files will be packaged with the application bundle, and loaded by `index.html`, eg:

```
  <body>
    <script src="%PUBLIC_URL%/env/config-override.js"></script>
    <script src="%PUBLIC_URL%/config.js"></script>
    <script>
      window.config = { ...config, ...config_override };
    </script>
    ...
  </body>
```

Then, [Nginx](https://www.nginx.com/) configuration can then be overriden to this way:

```
{{- $applicationConfigurationOverride := "config-override.js" -}}
{{- $configurationPath := "/usr/share/nginx/html/env" -}}
```