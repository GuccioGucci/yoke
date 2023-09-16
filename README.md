# yoke

![ci](https://github.com/GuccioGucci/yoke/actions/workflows/ci.yml/badge.svg) ![release](https://github.com/GuccioGucci/yoke/actions/workflows/release.yml/badge.svg)

* [About](#about)
  * [Motivation](#motivation)
  * [How it works](#how-it-works)
  * [Origin](#origin)
* [Installation](#installation)
  * [Archive: install script](#archive-install-script)
  * [Archive: self-extracting](#archive-self-extracting)
  * [Sources](#sources)
* [Usage](#usage)
  * [Update](#update)
  * [Install](#install)
  * [Lifecyle Hooks](#lifecyle-hooks)
  * [Helpers](#helpers)
* [Extra](#extra)
* [Contributing](#contributing)
  * [Tests](#tests)
  * [Contributions](/docs/EXTRA.md#contributions)
* [License](#license)

# About

`yoke` is a simple tool for deploying services on [Amazon Elastic Container Service](https://aws.amazon.com/ecs/) (AWS ECS). Its approach tries supporting [Continuous Delivery](https://continuousdelivery.com/), decoupling resources **provisioning** from application **deployment**, ensuring you can:

* **deploy a given application version**, to rollout new versions, or rollback to a previous version
* **build once, deploy everywhere**, decoupling build and deploy processes, given we correlate application version and deployment descriptors
* **keep application and deployment descriptors close together**, ensuring they stay in synch

Please, note that much of the context described here requires some basic knowledge of ECS concepts like *service* and *task-definition*.

# Motivation

In [GuccioGucci](https://github.com/GuccioGucci/) we've been using `ECS` for a long time, with a common setup: [Terraform](https://www.terraform.io/) for managing much of resource provisioning, and [`aws` cli](https://aws.amazon.com/cli/) for performing application deployment. We also relied on `FARGATE` launch type, wich ensure `ECS` is managing resources with no additional operations required.

When we tried applying Continuous Delivery, we faced the main issue with ECS: task definitions are *managed* resources as well, so created, updated and deleted by interacting with ECS, which track individual revisions for every change. In other words, to deploy a new application version on an ECS service, first we would have to update task definition, and then reference that task definition revision in deploying the service (this was done automatically, referring to latest revision).

One initial approach was keeping task definitions *stable*, while deploying *updated* application versions. This was achieved by using per-environment Docker image tags (eg: `application:dev`, `application:qa` and `application:prd`), and relying on **build** pipeline pushing new image version, and **deployment** pipeline tagging image accordingly to target environment. Then, it was just a matter of forcing a new deployment (`--force-new-deployment`) with [aws ecs update-service](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ecs/update-service.html).

But on the long run, even this approach was not enough. We faced it was not so easy to automatically evolve application code to use new configuration values (eg: injected as environment variables), since this typically required to prepare parameters with `aws` cli first, then enriching task-definition in Terraform modules and applying those changes. Two manual steps, before the new application version could be deployed. And this process had to be replicated in every `ECS` environment (eg: `dev`, `qa` and `prd`).

We then started looking for something supporting our scenario, and found it was quite common. Even if no single tooling existed matching our context, it was easy to glue together few open-source tools. Next section will explain how.

## How it works

Frankly speaking, it's just a wrapper around other tools (actually, [enriched forks](#contributing)):
* [silinternational/ecs-deploy](https://github.com/silinternational/ecs-deploy): simple script for deploying to AWS `ECS`. Itself, it's a wrapper around `aws` and `jq`
* [noqcks/gucci](https://github.com/noqcks/gucci): standalone [Go template engine](https://golang.org/pkg/text/templates/). (Isn't it funny that it is named `gucci`? Really!)

So, `yoke` it's mainly composing an `ecs-deploy` command-line, and additionally preparing a proper actual task-definition file, from given template and "values" YAML files (holding per-environment data).

## Origin

It was initially inspired by past experience with [Helm](https://helm.sh/), which is the [Kubernetes](https://kubernetes.io/) (k8s) package manager (in few words, the tool to discover and install k8s applications -- *charts* in Helm jargon).

Then the analogy was: `helm` (the ship's wheel) is for `k8s` (again, whit a seven spokes wheel icon) what `yoke` (the control wheel for airplanes) is for `ECS` (the "cloud")!

Anyway, if you don't get it, sounds like "joke".

![logo](/docs/logo-small.png "Logo")

# Installation

These are the dependencies required to be installed, part of them are from `ecs-deploy` [required dependencies](https://github.com/silinternational/ecs-deploy#installation):

* [aws](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) cli (version 2)
* [jq](https://github.com/stedolan/jq/wiki/Installation)
* [coreutils](https://www.gnu.org/software/coreutils/)
* [curl](http://curl.haxx.se/)

Additional dependencies (for both application and tests) expected to be available in the `PATH` will be automatically installed on first execution.

Given it's a `bash` script, it should be supported in most Unix-like OS. Most of development is done on MacOs, while automatic tests are run on Linux (Ubuntu and CentOS). On Windows, you'd probably only need a bash prompt such as [Git bash](https://gitforwindows.org/), [Cygwin](https://www.cygwin.com/) or similar (we succesfully tested on Windows 10 with `Git bash`, `aws` and `jq` - no extra `coreutils` and `curl` required). Anyway downloaded binaries are OS specific (eg: `gucci` is available for Windows starting from version `1.5.x`, 64-bit only at the moment).

## Archive: install script

Starting from version `2.2`, we added an `install.sh` script. Please, pick desired `yoke` distribution from [Releases](https://github.com/GuccioGucci/yoke/releases) page.

Here's how to install it (this will download and extract distribution archive, under `yoke` folder):

```
curl -L -s https://github.com/GuccioGucci/yoke/releases/download/2.2/install.sh | bash
```

You can then execute it with:

```
./yoke/yoke --version

Installing GuccioGucci/ecs-deploy 3.10.4 (ecs-deploy-3.10.4)
Linking ecs-deploy-3.10.4/ecs-deploy as ecs-deploy
Installing noqcks/gucci 1.5.2 (gucci-v1.5.2-darwin-amd64)
Linking gucci-1.5.2/gucci-v1.5.2-darwin-amd64
(templating) gucci: gucci version 1.5.1
(deployment) ecs-deploy: 3.10.4
```

## Archive: self-extracting

Starting from same version, we also provide a binary distributions, which actually are self-extracting archives (thanks to `makeself`).  See [makeself](https://github.com/megastep/makeself) to check compatibility with your OS.

Here's how to install it (this will extract the distribution archive and run a self-check `--version` execution):

```
curl -L -s https://github.com/GuccioGucci/yoke/releases/download/2.2/yoke.bin -o yoke.bin
chmod +x yoke.bin
./yoke.bin -- --version

Verifying archive integrity... MD5 checksums are OK. All good.
Uncompressing yoke
Installing GuccioGucci/ecs-deploy 3.10.4 (ecs-deploy-3.10.4)
Linking ecs-deploy-3.10.4/ecs-deploy as ecs-deploy
Installing noqcks/gucci 1.5.2 (gucci-v1.5.2-darwin-amd64)
Linking gucci-1.5.2/gucci-v1.5.2-darwin-amd64
(templating) gucci: gucci version 1.5.1
(deployment) ecs-deploy: 3.10.4
```

Please note that extra `--` before `--version`: that's required to instruct the self-extracting archive to pass arguments to `yoke` itself. Resources are extracted under `yoke` subfolder, and once extracted, `yoke` can be executed from subfolder.

```
.
├── yoke
│   ├── LICENSE
│   ├── bin
│   ├── lib
│   └── yoke
└── yoke.bin
```

```
./yoke/yoke --version

(templating) gucci: gucci version 1.5.1
(deployment) ecs-deploy: 3.10.4
```

Then, you can safely delete binary distribution file, or keep it as a wrapper, if you like it (it would always self-extract, before executing).

## Sources

As an alternative, here's how to install `yoke` from sources:

```
$ git clone https://github.com/GuccioGucci/yoke.git
$ cd yoke
$ ./yoke --version

Installing GuccioGucci/ecs-deploy 3.10.4 (ecs-deploy-3.10.4)
Linking ecs-deploy-3.10.4/ecs-deploy
Installing noqcks/gucci 1.5.2 (gucci-v1.5.2-darwin-amd64)
Linking gucci-1.5.2/gucci-v1.5.2-darwin-amd64
(templating) gucci: gucci version 1.5.1
(deployment) ecs-deploy: 3.10.4
```

# Usage

In order to use it, please ensure you have a proper AWS setup, ensuring `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables are set, or alternatively `AWS_SHARED_CREDENTIALS_FILE` only. Please, remember also to configure default region, by choosing "Default region name" value with `aws configure`, or setting `AWS_DEFAULT_REGION` environment variable.

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
    -t|--tag value          Docker image tag (eg: 8a5f3a7-88)
    -w|--working-dir value  where to search for resources (default: deployment)
    -f|--values value       values file (eg: values-dev.yaml)
    --prune value           only keep given task definitions (eg: 5)
    --timeout value         timeout (default: 300)
    --dry-run               dry-run mode, avoid any deployment (default: true)
```

`yoke` supports two different modes: **update** mode and **install** mode. Given your context (migrating an existing application, or developing a new application) you can choose the one that fits you best. Please, see next sections for details, and [Provisioning: Terraform](/docs/EXTRA.md#provisioning-terraform) section to understand the impact on resource provisioning.

## Update

Update an existing task definition, with a given image tag (short and long versions):
```
./yoke update -c cls01 -s hello-world-dev -t bb255ec-93
./yoke update --cluster cls01 --service hello-world-dev --tag bb255ec-93
```

This will grab the *current* task definition (for given `cls01` cluster and `hello-world-dev` service), update main container definition to use the given image tag (`bb255ec-93`), create a new revision for the task definition, and finally force a new deployment. Once done, newly created task definition will be the *current* one.

## Install

Install local task definition, with image tag (short and long versions):
```
./yoke install -c cls01 -s hello-world-dev -t bb255ec-93 -w test/samples/hello-world/deployment -f values-dev.yaml
./yoke install --cluster cls01 --service hello-world-dev --tag bb255ec-93 --working-dir test/samples/hello-world/deployment --values values-dev.yaml
```

This will prepare a local task definition, starting from a template (expected to be `task-definition.json.tmpl`), apply the proper template substitutions (using given `values-dev.yaml` file as source), create a new revision for the task definition (starting from the local one, just created), and finally force a new deployment. Once done, newly created task definition will be the *current* one.

Both task definition template (`task-definition.json.tmpl`) and values file (`values-dev.yaml` in the example) are expected to be found in the working directory (default to `deployment`, set to `test/samples/hello-world/deployment` in the example). Relying on the default, it would be:
```
deployment/
├── task-definition.json.tmpl
├── values-dev.yaml
├── values-qa.yaml
└── values-prd.yaml
```

Expected `task-definition.json.tmpl` content is a JSON file, with a `taskDefinition` root node matching the [aws ecs register-task-definition](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ecs/register-task-definition.html) JSON syntax. Here's a minimal template, see [Deployment](/docs/EXTRA.md#deployment) Templates section for a complete example:

```
{
  "taskDefinition": {
    "family": "...",
    "executionRoleArn": "...",
    "taskRoleArn": "...",
    "placementConstraints": [ ],
    "requiresCompatibilities": [ "FARGATE" ],
    "networkMode": "...",
    "cpu": "...",
    "memory": "...",
    "volumes": [ ],
    "containerDefinitions": [
      {
        "name": "application",
        "image": "...",
        "portMappings": [ { "containerPort": ... } ],
        "environment": [ ],
        "secrets": [ ]
      }
    ]
  }
}
```

Please, while preparing per-environment `environment` values in `containerDefinitions` nodes, consider if those environment variables could be part of proper application configuration (specific to your programming language or framework). In that case, see [Application configuration override](/docs/EXTRA.md#application-configuration-override) section in [Extra](/docs/EXTRA.md).

## Lifecyle Hooks

Additional actions can be performed hooking into particular lifecycle events. Script templates are expected to be found in `bin` folder, under current working-dir. As usual, you can use values from value file, if set in the command line.

Currently the only supported hooks are `pre` and `post`, for pre-deploy and post-deploy actions:

```
deployment/
└── bin
    ├── post.sh.tmpl
    └── pre.sh.tmpl
```

Any already set environment variable would still be available. In addition, few other environment variables are set, for convenience (see [test/deployments/lifecycle_post_deploy/bin/pre.sh.tmpl](test/deployments/lifecycle_post_deploy/bin/pre.sh.tmpl) and [test/deployments/lifecycle_post_deploy/bin/post.sh.tmpl](test/deployments/lifecycle_post_deploy/bin/post.sh.tmpl) for a full example):

* `ECS_CLUSTER`: current cluster (valued after `--cluster` parameter)
* `ECS_SERVICE`: current service (valued after `--service` parameter)
* `ECS_IMAGE_TAG`: current version (valued after `--tag` parameter)

As an example, you could provide a `pre` hook for validating [Application configuration override](/docs/EXTRA.md#application-configuration-override), before using it as part of a deployment. Say it's a plain JSON file, you could use `jq` to simply check it can be successfully parsed (see [here](https://stackoverflow.com/questions/46954692/check-if-string-is-a-valid-json-with-jq) for an hint).

An example of `post` hook would be invalidating a Cloudfront distribution, caching content for your ECS service. In that case, you can rely on [aws_cf_distribution](#aws_cf_distribution) helper script, to retrive distribution id.

## Helpers

While preparing template content, you can use much of Go templating functions: for example, declaring variables, `if` statements, boolean functions and so on. Also, Sprig functions are supported. Please, see [here](https://github.com/noqcks/gucci#templating) for the full list of supported functions and options.

In addition to that, we prepared some useful helper scripts (already available into `PATH`), that you can use with the `shell` function. Following sections will recap them (see [helpers](/bin/helpers) for details, and [helpers.bats](/test/unit/helpers.bats) for usage examples).

One last note, custom helpers are also supported. They're expected to be found in `bin` folder, under current working-dir. For example, you can define a custom `my_helper` script and run it from the task definition template:

```
deployment/
└── bin/
    └── my_helper
```

```
"executionRoleArn": "{{ shell "my_helper hello-world-" .environment.name }}"
```

### aws_account_id

Get current Account id.

* Usage: `aws_account_id`
* Example:
```
"executionRoleArn": "arn:aws:iam::{{ shell "aws_account_id" }}:role/hello-world-{{ .environment.name }}"
```

### aws_iam_role

Get [IAM](https://aws.amazon.com/iam/) Role by name, then extract ARN.

* Usage: `aws_iam_role $NAME`
* Example (this is equivalent to the previous one):
```
"executionRoleArn": "{{ shell "aws_iam_role hello-world-" .environment.name }}"
```

### aws_efs_ap

Get [EFS](https://aws.amazon.com/efs/) Access Point by `Name` tag, then extract requested attribute. `Name` tag usage is required since there is no clear id on those resources. So, to be uniquely identified, please add this tag to desired access points, in your provisioning configuration (eg: Terraform module).

* Usage: `aws_efs_ap $NAME $ATTRIBUTE`
* Example:
```
"fileSystemId": "{{ shell "aws_efs_ap hello-world-" .environment.name "-efs fileSystemId" }}"
...
"accessPointId": "{{ shell "aws_efs_ap hello-world-" .environment.name "-efs accessPointId" }}"
```

### aws_lb_target_group

Get Load Balancer Target Group by name, then extract ARN.

* Usage: `aws_lb_target_group $NAME`
* Example:
```
"targetGroupArn": "{{ shell "aws_lb_target_group hello-world-" .environment.name "-tg" }}"
```

### aws_security_group

Get Security Group by name, then extract ARN.

* Usage: `aws_security_group $NAME`
* Example:
```
"securityGroups": [ "{{ shell "aws_security_group hello-world-" .environment.name "-sg" }}" ]
```

### aws_subnet

Get Subnet by name, then extract ARN.

* Usage: `aws_subnet $NAME`
* Example:
```
"subnets": [
  "{{ shell "aws_subnet nonprod-az1" }}",
  "{{ shell "aws_subnet nonprod-az2" }}"
]
```

### aws_cf_distribution

Get [CloudFront](https://aws.amazon.com/cloudfront/) distribution id, by `Comment`. `Comment` usage is required since there is id is automatically generated, and not controlled by configuration. So, to be uniquely identified, please add this comment to desired distribution, in your provisioning configuration (eg: Terraform module). Note that, we're not using `Tags` node here, since it would require two API calls (see [list-distributions](https://docs.aws.amazon.com/cli/latest/reference/cloudfront/list-distributions.html) and [list-tags-for-resource](https://docs.aws.amazon.com/cli/latest/reference/cloudfront/list-tags-for-resource.html)).


* Usage: `aws_cf_distribution $VALUE`
* Note: this is intended to be used as part of post-deploy actions

# Extra

We prepared some resources and guidelines in adopting the process, for example ready to use **templates** for deployment and build servers (such as [Jenkins](https://www.jenkins.io/)), or configuring **deployment controllers** (for Rolling Update and Canary Releases). Please, note that this additional contribution is partly very specific to what we've been using in [GuccioGucci](https://github.com/GuccioGucci/), anyway we hope it's common enough to be useful to you as well. See [EXTRA.md](/docs/EXTRA.md)

# Contributing

## Tests

Yes, it's tested! We were able to cover basic command-line parsing, and even tested expected interaction with `ecs-deploy`, relying on a [fake version](/test/fake/lib/ecs-deploy). So, no real AWS integration happening, test execution is safe!

To run tests, execute:

```
./build.sh
```

These are the libs we're using:

* https://github.com/sstephenson/bats
* https://github.com/ztombol/bats-docs
  * https://github.com/ztombol/bats-support
  * https://github.com/ztombol/bats-assert

Additionally, in [GuccioGucci](https://github.com/GuccioGucci/) we take care of ensuring end-to-end build and deployment is still working, with few sample applications, on our AWS `ECS` clusters (and then using `yoke` in our daily deployments).

## Contributions

Here's a list of contributions we did to involved open-source projects:

* [silinternational/ecs-deploy](https://github.com/silinternational/ecs-deploy) (forked to [GuccioGucci/ecs-deploy](https://github.com/GuccioGucci/ecs-deploy))
  * confirmed a bug on task-definition file not working, [here](https://github.com/silinternational/ecs-deploy/pull/215)
  * PR to migrate `--tag-only` to apply on main container definition only (being the first one), [here](https://github.com/silinternational/ecs-deploy/pull/227)
  * PR to support canary releases on `EXTERNAL` deployments, [here](https://github.com/silinternational/ecs-deploy/pull/231)
* [noqcks/gucci](https://github.com/noqcks/gucci) (forked to [GuccioGucci/gucci](https://github.com/GuccioGucci/gucci))
  * PR on enriching shell function to support multiple arguments, [here](https://github.com/noqcks/gucci/pull/30)
  * PR on enriching shell function to track error details on failure, [here](https://github.com/noqcks/gucci/pull/41)

Note that while waiting for some PR to be merged, we're using forks.

# License

Copyright 2021 Gucci.

Licensed under the [GNU Lesser General Public License, Version 3.0](http://www.gnu.org/licenses/lgpl.txt)