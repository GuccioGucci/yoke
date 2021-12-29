# Table of contents

* [About](#about)
  * [Motivation](#motivation)
  * [How it works](#how-it-works)
  * [Origin](#origin)
* [Usage](#usage)
  * [Update](#update)
  * [Install](#install)
  * [Helpers](#helpers)
* [Provisioning: Terraform](#provisioning-terraform)
  * [Mixed: managed and live (migrating to Update mode)](#mixed-managed-and-live)
  * [Afterwards: live only (migrating to Install mode)](#afterwards-live-only)
  * [Bootstrap: live only, with bogus (creating from scratch)](#bootstrap-live-only-with-bogus)
* [Extra](#extra)
  * [Templates](#templates)
    * [Deployment](#deployment)
    * [Pipelines: Jenkins](#pipelines-jenkins)
  * [Application configuration override](#application-configuration-override)
* [Contributing](#contributing)
  * [Tests](#tests)
  * [Contributions](#contributions)

<a name='about'></a>
# About

`yoke` is a simple tool for deploying services on [Amazon Elastic Container Service](https://aws.amazon.com/ecs/) (AWS ECS). Its approach tries supporting [Continuous Delivery](https://continuousdelivery.com/), decoupling resources **provisioning** from application **deployment**, ensuring you can:

* **deploy a given application version**, to rollout new versions, or rollback to a previous version
* **build once, deploy everywhere**, decoupling build and deploy processes, given we correlate application version and deployment descriptors
* **keep application and deployment descriptors close together**, ensuring they stay in synch

<a name='motivation'></a>
# Motivation

In [GuccioGucci](https://github.com/GuccioGucci/) we've been using ECS for a long time, with a common setup: [Terraform](https://www.terraform.io/) for managing much of resource provisioning, and [`aws` CLI](https://aws.amazon.com/cli/) for performing application deployment.

When we tried applying Continuous Delivery, it was not so easy to automatically evolve application code to use new configuration values (eg: injected as environment variables), since this typically required to prepare parameters with `aws` CLI first, then enriching task-definition in `Terraform` modules and applying those changes. Two manual steps, before the new application version could be deployed. And this process had to be replicated in every ECS environment (eg: `dev`, `qa` and `prd`).

We then started looking for something supporting our scenario, and found it was quite common. Even if no single tooling existed matching our context, it was easy to glue togheter few open-source tools. Next section will explain how.

<a name='how-it-works'></a>
## How it works

Frankly speaking, it's just a wrapper around other tools:
* [silinternational/ecs-deploy](https://github.com/silinternational/ecs-deploy): simple script for deploying to AWS ECS. Itself, it's a wrapper around `aws` and `jq`
* [noqcks/gucci](https://github.com/noqcks/gucci): standalone [Go template engine](https://golang.org/pkg/text/templates/). (Isn't it funny that it is named `gucci`? Really!)

So, `yoke` it's mainly composing an `ecs-deploy` command-line, and additionally preparing a proper actual task-definition file, from given template and "values" YAML files (holding per-environment data).

<a name='origin'></a>
## Origin

It was initially inspired by past experience with [Helm](https://helm.sh/), which is the Kubernetes (k8s) package manager (in few words, the tool to discover and install k8s applications -- *charts* in Helm jargon).

Then the anology was: `helm` (the ship's wheel) is for `k8s` (again, whit a seven spokes wheel icon) what `yoke` (the control wheel for airplanes) is for `ECS` (the "cloud")!

Anyway, if you don't get it, sounds like "joke".

![flight yoke system](docs/flight-yoke-system.jpg "Flight yoke system")

<a name='usage'></a>
# Usage

Usage help:

```
usage: ./yoke command [parameters]

command:
    update                  update remote task definition with given image tag
    install                 install local task definition (task-definition.json.tmpl), using given image tag

parameters:
    -h|--help               show this usage
    -v|--version            show version info
    -d|--debug              debug mode, verbose (default: false)
    -c|--cluster value      ecs cluster (eg: cls01)
    -s|--service value      ecs service (eg: hello-world-dev)
    -t|--tag value          docker image tag (eg: 8a5f3a7-88)
    -w|--working-dir value  where to search for resources (default: deployment)
    -f|--values value       values file (eg: values-dev.yaml)
    --prune value           only keep given task definitions (eg: 5)
    --timeout value         timeout (default: 300)
    --dry-run               dry-run mode, avoid any deployment (default: true)
```

`yoke` supports two different modes: **update** mode and **install** mode. Given your context (migrating an existing application, or developing a new application) you can choose the one that fits you best. Please, see next sections for details, and [Provisioning: Terraform](#provisioning-terraform) section to understand the impact on resource provisioning.

<a name='update'></a>
## Update

Update an existing task definition, with a given image tag (short and long versions):
```
./yoke update -c cls01 -s hello-world-dev -t bb255ec-93
./yoke update --cluster cls01 --service hello-world-dev --tag bb255ec-93
```

This will grab the *current* task definition (for given `cls01` cluster and `hello-world-dev` service), update main container definition to use the given image tag (`bb255ec-93`), create a new revistion for the task definition, and finally force a new deployment. Once done, newly created task definition will be the *current* one.

<a name='install'></a>
## Install

Install local task definition, with image tag (short and long versions):
```
./yoke install -c cls01 -s hello-world-dev -t bb255ec-93 -w test/samples/hello-world/deployment -f values-dev.yaml
./yoke install --cluster cls01 --service hello-world-dev --tag bb255ec-93 --working-dir test/samples/hello-world/deployment --values values-dev.yaml
```

This will prepare a local task definition, starting from a template (expected to be `task-definition.json.tmpl`), apply the proper template substitutions (using given `values-dev.yaml` file as source), create a new revision for the task definition (starting from the local one, just created), and finally force a new deployment. Once done, newly created task definition will be the *current* one.

Both task definition template (`task-definition.json.tmpl`) and values file (`values-dev.yaml` in the exaple) are expected to be found in a working directory (default to `deployment`, set to `test/samples/hello-world/deployment` in the example). Relying on the default, it would be:
```
deployment/
├── task-definition.json.tmpl
├── values-dev.yaml
├── values-qa.yaml
└── values-prd.yaml
```

<a name='helpers'></a>
## Helpers

For the template (`task-definition.json.tmpl`) you can use some supported functions (see [here](https://github.com/noqcks/gucci#templating) for the full list). In addition to that, we prepared some useful helper scripts, you can use with the `shell` function. Here they are (available in [helpers](bin/helpers), usage examples in [helpers.bats](test/helpers.bats)):

* `aws_account_id`: get current AWS account id. Example:
```
"executionRoleArn": "arn:aws:iam::{{ shell "aws_account_id" }}:role/hello-world-{{ .environment.name }}"
```

* `aws_iam_role $NAME`: get IAM role by name, then extract ARN. Example (this is equivalent to the previous one):
```
"executionRoleArn": "{{ shell "aws_iam_role hello-world-" .environment.name }}"
```

* `aws_efs_ap $NAME $ATTRIBUTE`: get EFS access point by `Name` tag, then extract requested attribute. Tag usage is to overcome no clear ID on those resources, to be uniquely identified. Example:
```
"fileSystemId": "{{ shell "aws_efs_ap hello-world-" .environment.name "-efs fileSystemId" }}"
...
"accessPointId": "{{ shell "aws_efs_ap hello-world-" .environment.name "-efs accessPointId" }}"
```

<a name='provisioning-terraform'></a>
# Provisioning: Terraform

You're probably guessing what's the impact on provisioning, once we move task-definition out of Terraform scope. Here's an [interesing discussion on the topic](https://github.com/hashicorp/terraform-provider-aws/issues/632), with alternative approaches. We'll try to recap here, with examples.

<a name='mixed-managed-and-live'></a>
## Mixed: managed and live (migrating to Update mode)

One approach is to rely on both a `resource` for *managed* task definition, and also a `data` to get current *live* task definition in the ECS environment. Then, on task definition `resource`, you can pick the "latest" one, being either *managed* or *live* one (latest meaning being the biggest of them).

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

<a name='afterwards-live-only'></a>
## Afterwards: live only (migrating to Install mode)

Another approach, going even furher, is getting rid of `resource` for *managed* task definition, and only relying on `data` for *live* task definition, using it to configure the service. Of course, this can only be achieved once the task definition has already been created! So for example, that could be done to migrate an existing service, from a previously "all-managed" approach.

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

<a name='bootstrap-live-only-with-bogus'></a>
## Bootstrap: live only, with bogus (creating from scratch)

Even better, we could always rely on existing task definitions, but using some default "off-the-shelf" ones the very first time (while creating), and then stick to previous solution, afterwards. This can be achieved using a variable on command-line (e.g. `bootstrap`), being `false` by default and set `true` on first execution.

Here's an example:

```
# first time
terraform apply -var bootstrap=true

# following executions
terraform apply
```

So the only change, in respect to previous example, is to pick the proper task definition, accordingly to bootstrap.

* `module.tf`
```
variable "bootstrap" {}

locals {
  ...
  container_port = 8090
  task_definition_family = var.bootstrap ? "bogus-${local.container_port}" : "${var.stage}-${local.svc_name}"
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

You can then prepare soe `bogus` task definitions, just for this reason, in any target environment (eg: **nonprod**, **prod**). They would be named after the HTTP port they expose, in order to configure the proper one, accordingly to current application behaviour:

* `bogus-8080`
* `bogus-8090`
* ...

They are expected to reply with a proper `200 OK` on any endpoint, so you could configure the proper health-check as it would be for the application. For details, see [bogus docker images](docker/bogus).

Please, note that in order to migrate from bogus to application task definition, you have to keep the same container **name**, otherwise the the load balancer would fail to re-configure. For example, use `application` as a name for this.

```
resource "aws_ecs_service" "esv" {
  ...
  load_balancer {
    ...
    container_name = "application"
  }
}
```

As reference, here's a [description of the approach](https://github.com/hashicorp/terraform-provider-aws/issues/632#issuecomment-472420686), from the previously shared discussion on the topic.

<a name='extra'></a>
# Extra

This section contains resources and guidelines in adopting the process. Please, consider this additional contribution as being very specific to what we've been using in [GuccioGucci](https://github.com/GuccioGucci/), anyway we hope it's common enough to be useful to you as well.

<a name='templates'></a>
## Templates

<a name='deployment'></a>
### Deployment

A deployment template is provided in [templates/deployment](templates/deployment). Copy & paste it in your application suorces, for example on root folder.

Sample values files should be ready to be used, while you should edit [`task-definition.json.tmpl`](templates/deployment/task-definition.json.tmpl):

* replace `${APPLICATION}` with your application name. This is also expected to be the docker repository image name
* replace `${CONTAINER_PORT}` with load-balanced HTTP port for your application, as in your provisioning configuration (eg: Terraform)
* replace `${SERVICE}` with your service name, in order match `${SERVICE}-{{ .environment.name }}` with your provisioning configuration (eg: Terraform)

<a name='pipelines-jenkins'></a>
### Pipelines: Jenkins

In order to integrate with [Jenkins](https://www.jenkins.io/), sample templates are provided in [templates/pipeline](templates/pipeline):

* [`Jenkinsfile`](templates/pipeline/Jenkinsfile) is the main pipeline, orchestrating build & test and deployment on all environments (DEV, PROD)
  * set `APPLICATION` to your application name. This is also expected to be the docker repository image name
  * create a Jenkins job using this `Jenkinsfile` as the pipeline
* [`Jenkinsfile.deploy`](templates/pipeline/Jenkinsfile.deploy) is the deployment pipeline, interacting with yoke in order to deploy on ECS
  * set `APPLICATION` to your application name (as in previous step)
  * set `SERVICE` to your service name, in order match `${params.ENVIRONMENT}-${SERVICE}` with your Terraform configuration
  * create a Jenkins job using this `Jenkinsfile.deploy` as the pipeline, named `${APPLICATION}_deploy`

Then, in `Jenkinsfile.deploy` please consider using in a specific tag instead of relying on `master` branch, in order to keep control of yoke version, since it lacks any proper distribution channel at the moment (nexus, yum, etc.). To do so, please set `YOKE_VERSION` to any available tag. See [CHANGELOG](CHANGELOG.md) for details about individual versions.

<a name='application-configuration-override'></a>
## Application configuration override

Given task-definition is prepared at deploy-time, it could be used to apply override application configurations, with external resources. In other words, instead of relying on a bunch of enviroment variables, defined in every value file, we can leverage on language or framework specific tecniques for injecting complete application configuration file, for a given environemnt, at run-time (you'd probably leave few environment variables anyway, eg: those used by Dockerfile or other resources).

The overall approach is documented [here](https://kichik.com/2020/09/10/mounting-configuration-files-in-fargate/), and it's easily adapted from CloudFormation. In few words

* a dedicated *ephemeral* `application-config` container is defined, with the only purpose of creating a dedicated configuration file. Configuration file's content is read from a `$DATA` environment variable
* `application` container depends on `application-config` container to be COMPLETE (so it can then terminate, once done). This is to ensure configuration file would already be prepared, at application startup
* `$DATA` environment variable into `application-config` container definition is then valued with original file content, encoded to base64 (that should preserve any special char and newlines)

Here's a draft `task-definition.json.tmpl`:

```
{{/*
  $configurationPath and $applicationConfigurationOverride are set to match docker configuration (eg: Jib, Dockerfile or other tooling for preparing docker images)
  please keep them in synch, would they be migrated.
*/}}
{{- $applicationConfigurationOverride := "..." -}} # eg: application-override.yaml
{{- $configurationPath := "..." -}} # eg: /app/config
{
  "taskDefinition": {
   ...
    "volumes": [
      {
        "host": {
        },
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

For example, with `Ktor` and `Jib`, you'd probably need:

```
{{- $applicationConfigurationOverride := "application-override.conf" -}}
{{- $configurationPath := "/app/resources/config" -}}
```

Then, you only need to enable overriding in `Ktor` application config, relying on [HOCON "include"](https://github.com/lightbend/config/blob/main/HOCON.md#includes) capability, adding this as the very last line in application.conf file:
```
include "config/application-override.conf"
```

For `Spring Boot` application, you'd probably need:

```
{{- $applicationConfigurationOverride := "application-override.properties" -}} # or application-override.yaml
{{- $configurationPath := "/opt/service/config" -}}
```

Then, add this to application startup command line (eg: `Dockerfile`, `bootstrap.sh` or equivalent):
```
java -jar service.jar ... \
     --spring.config.additional-location=config/application-override.properties # or application-override.yaml
```

Finally, you can prepare env-specific application configuration overrides, under same working-dir folder (eg: `deployment`):
```
deployment/
└── config/
    ├──dev/
    |  └── application-override.conf
    ├──qa/
    |  └── application-override.conf
    └──prd/
       └── application-override.conf
```

<a name='contributing'></a>
# Contributing

<a name='tests'></a>
## Tests

Yes, it's tested! We were able to cover basic command-line parsing, and even tested expected interaction with `ecs-deploy`, relying on a [fake version](test/fake/lib/ecs-deploy). So, no real AWS integration happening, test execution is safe!

To run tests, execute:

```
./build.sh
```

These are the libs we're using:

* https://github.com/sstephenson/bats
* https://github.com/ztombol/bats-docs
  * https://github.com/ztombol/bats-support
  * https://github.com/ztombol/bats-assert

<a name='contributions'></a>
## Contributions

Here's a list of contributions we did to involved open-source projects:

* [silinternational/ecs-deploy](https://github.com/silinternational/ecs-deploy)
  * confirmed a bug on task-definition file not working, [here](https://github.com/silinternational/ecs-deploy/pull/215)
  * PR to migrate --tag-only to apply on main container definition only (being the first one), [here](https://github.com/silinternational/ecs-deploy/pull/227)
  * PR to support canary releases on EXTERNAL deployments, [here](https://github.com/silinternational/ecs-deploy/pull/231)
* [noqcks/gucci](https://github.com/noqcks/gucci)
  * PR on enriching shell function to support multiple arguments, [here](https://github.com/noqcks/gucci/pull/30)