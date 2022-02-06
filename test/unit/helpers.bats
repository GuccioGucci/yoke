load '../../lib/bin/bats-support/load'
load '../../lib/bin/bats-assert/load'

setup() {
    export PATH="$( realpath test/bin/helpers ):$( realpath test/fake/platform ):$( realpath test/fake/lib ):$PATH"
    export YOKE_FAKES_LOGGING="$BATS_TMPDIR/yoke/$RANDOM/commands.log"
    mkdir -p "$( dirname $YOKE_FAKES_LOGGING )"
}

teardown() {
    rm -rf "$( dirname $YOKE_FAKES_LOGGING )"
}

@test 'helpers with arguments' {
    run ./yoke install -c any -s any -t 12345 -w test/deployments/task_definition_template_with_arguments -f values-dev.yaml
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    assert_equal $status 0 || fail "${lines[@]} ($commands)"
    
    local task_definition="$( echo $commands | grep -o '/tmp/task-definition\.json.\w*' )"
    local container_port="$( cat $task_definition | jq -r ".taskDefinition.containerDefinitions[0].portMappings[0].containerPort" )"
    assert_equal "$container_port" "8080"

    local family="$( cat $task_definition | jq -r ".taskDefinition.family" )"
    assert_equal "$family" "hello-world-dev"
    
    local service_name="$( cat $task_definition | jq -r ".taskDefinition.containerDefinitions[0].environment[0].value" )"
    assert_equal "$service_name" "hello-world-dev"
}

@test 'helpers with arguments, from current deployment PATH' {
    run ./yoke install -c any -s any -t 12345 -w test/deployments/task_definition_template_from_current_deployment -f values-dev.yaml --debug
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    assert_equal $status 0 || fail "${lines[@]} ($commands)"
    
    local task_definition="$( echo $commands | grep -o '/tmp/task-definition\.json.\w*' )"
    local container_port="$( cat $task_definition | jq -r ".taskDefinition.containerDefinitions[0].portMappings[0].containerPort" )"
    assert_equal "$container_port" "8080"

    local family="$( cat $task_definition | jq -r ".taskDefinition.family" )"
    assert_equal "$family" "hello-world-dev"
    
    local service_name="$( cat $task_definition | jq -r ".taskDefinition.containerDefinitions[0].environment[0].value" )"
    assert_equal "$service_name" "hello-world-dev"
}

@test 'aws account id - success' {
    run ./bin/helpers/aws_account_id
    local commands="$( cat $YOKE_FAKES_LOGGING )"

    assert_equal $status 0 || fail "${lines[@]} ($commands)"
    assert_equal "${lines[0]}" "123456789012"
}

@test 'aws account id - template' {
    run ./yoke install -c any -s any -t 12345 -w test/deployments/aws_account_id
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    assert_equal $status 0 || fail "${lines[@]} ($commands)"

    local task_definition="$( echo $commands | grep -o '/tmp/task-definition\.json.\w*' )"    
    local execution_role="$( cat $task_definition | jq -r ".taskDefinition.executionRoleArn" )"
    assert_equal "$execution_role" "arn:aws:iam::123456789012:role/helpers"
}

@test 'aws iam role - found' {
    run ./bin/helpers/aws_iam_role hello-world-dev
    local commands="$( cat $YOKE_FAKES_LOGGING )"

    assert_equal $status 0 || fail "${lines[@]} ($commands)"
    assert_equal "${lines[0]}" "arn:aws:iam::123456789012:role/hello-world-dev"
}

@test 'aws iam role - not found' {
    run ./bin/helpers/aws_iam_role not-found-role
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    
    assert_equal $status 1 || fail "${lines[@]} ($commands)"
    assert_equal "${lines[0]}" "NOT-FOUND[not-found-role]"
}

@test 'aws iam role - template' {
    run ./yoke install -c any -s any -t 12345 -w test/deployments/aws_iam_role
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    assert_equal $status 0 || fail "${lines[@]} ($commands)"

    local task_definition="$( echo $commands | grep -o '/tmp/task-definition\.json.\w*' )"
    local execution_role="$( cat $task_definition | jq -r ".taskDefinition.executionRoleArn" )"
    assert_equal "$execution_role" "arn:aws:iam::123456789012:role/hello-world-dev"
}

@test 'aws efs ap - found' {
    run ./bin/helpers/aws_efs_ap hello-world-dev-efs fileSystemId
    local commands="$( cat $YOKE_FAKES_LOGGING )"

    assert_equal $status 0 || fail "${lines[@]} ($commands)"
    assert_equal "${lines[0]}" "fs-12345678"
}

@test 'aws efs ap - not found' {
    run ./bin/helpers/aws_efs_ap not-found-efs fileSystemId
    local commands="$( cat $YOKE_FAKES_LOGGING )"

    assert_equal $status 1 || fail "${lines[@]} ($commands)"
    assert_equal "${lines[0]}" "NOT-FOUND[not-found-efs,fileSystemId]"
}

@test 'aws efs ap - template' {
    run ./yoke install -c any -s any -t 12345 -w test/deployments/aws_efs_ap
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    assert_equal $status 0 || fail "${lines[@]}"

    local task_definition="$( echo $commands | grep -o '/tmp/task-definition\.json.\w*' )"    
    local file_system_id="$( cat $task_definition | jq -r ".taskDefinition.volumes[0].efsVolumeConfiguration.fileSystemId" )"
    assert_equal "$file_system_id" "fs-12345678"
    
    local file_system_id="$( cat $task_definition | jq -r ".taskDefinition.volumes[0].efsVolumeConfiguration.authorizationConfig.accessPointId" )"
    assert_equal "$file_system_id" "fsap-1234567890123456789"
}

@test 'aws cf distribution - found' {
    run ./bin/helpers/aws_cf_distribution hello-world-dev
    local commands="$( cat $YOKE_FAKES_LOGGING )"

    assert_equal $status 0 || fail "${lines[@]} ($commands)"
    assert_equal "${lines[0]}" "XYZWKXYZWKABC"
}

@test 'aws cf distribution - not found' {
    run ./bin/helpers/aws_cf_distribution not-found-cf
    local commands="$( cat $YOKE_FAKES_LOGGING )"

    assert_equal $status 1 || fail "${lines[@]} ($commands)"
    assert_equal "${lines[0]}" "NOT-FOUND[not-found-cf]"
}