# Changelog

Versions before 2.0 were only available on internal repository, before open-sourcing the project.

## Current

* helpers: aws_cf_distribution
* updated dependencies: gucci to 1.5.4 (fork)
* templates, helpers: stdout as error detail, on failure
* deployment lifecycle: post-deploy (eg. custom cache invalidation)

## 2.5

* updated dependencies: ecs-deploy to 3.10.6 (fork)
* rollback, mode info: current task definition containers' image, more info
* dry-run mode, delegating to ecs-deploy

## 2.4

* updated dependencies: ecs-deploy to 3.10.5 (fork)
* rollback, mode info: current task definition containers' image

## 2.3

* updated dependencies: ecs-deploy to 3.10.4 (fork)
* support for path with spaces

## 2.2

* dependencies: migrated from lib/update to bin/install
* dependencies: install exact version for ecs-deploy and gucci
* dependencies: install `--all`, `--app` or `--test` only libraries
* dependencies: downloaded, installed and linked
* distribution as binary packages: archive and self-executable archive

## 2.1

* updated dependencies: gucci to 1.5.2
* minimal support for Windows
* helpers from working-dir
* canary releases: update, supporting confirmation (default or custom)
* updated dependencies: ecs-deploy to 3.10.3 (fork)

## 2.0

* open-sourcing: initial import, from private repo
* open-sourcing: apps and test dependencies to lib, installed at run-time
* check required dependencies

## 1.6

* updated dependencies: ecs-deploy to 3.10.2 (fork)
* canary releases: 25% canary + stable rollout
* canary releases: task-set from file
* canary releases: custom confirm script
* canary releases: support for creating initial PRIMARY deployment
* gucci: shell running in working directory (for processing custom files, in deployments folder)

## 1.5

* helpers: aws iam role, as a more compact alternative to aws account id for roles
* install: validation, avoid deploying failing task-definition
* dry-run mode, to avoid any deployment execution (helping testing and troubleshooting)
* updated dependencies: ecs-deploy to 3.10.1 (fork)
* multi-container mode, applying image tag to main container only (first one)
* updated dependencies: gucci to 1.4.0 (merged from fork)

## 1.4

* updated dependencies: gucci to 1.3.1 (fork)
* helpers: support for shell with multiple arguments (eg: for dynamic EFS access point names)

## 1.3

* install, even without values (only template, expected to be reused)
* helpers: support for EFS access points (volumes / mounts)

## 1.2

* added templates: deployment, pipelines
* updated dependencies: ecs-deploy to 3.10.0, gucci to 1.3.0

## 1.1

* docker images, for supporting **bootstrap** mode in Terraform
* timeout, by command-line

## 1.0

* relocated under `gcicd` project, updated resources accordingly

## 0.5

* 5 minutes timeout, by default

## 0.4

* helper function: `aws_account_id`

## 0.3

* better README, with samples for Jenkins and Terraform
* renamed script to yoke

## 0.2

* added "prune", for removing older task definitions

## 0.1

* initial version, with support for "update" and "install"

# TODO

* rollback, by default or optionally
* canary release: more complex scenario
* deploy scheduled tasks
* support for secrets