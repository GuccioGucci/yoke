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

last_execution_output() {
    printf '%s\n' "${lines[@]}"
}

# NOTE: please, keep path-related assertion to something like this:
#   /tmp/task-set\.json.\w*
# and NOT like this:
#   .*/task-definition\.json.\d*
# This is due to a dependency with Jenkins node, not able to support the first version (even if they're equivalent :()

@test 'update - image tag only' {
    run ./yoke update -c cls01 -s hello-world-dev -t bb255ec-93

    local commands="$( cat $YOKE_FAKES_LOGGING )"
    assert_equal $status 0 || fail "$commands"
    
    local expected='ecs-deploy -c cls01 -n hello-world-dev --tag-only bb255ec-93 -i ignored-image'
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'install - task definition, with image tag' {
    run ./yoke install -c cls01 -s hello-world-dev -t bb255ec-93 -w test/samples/hello-world/deployment -f values-dev.yaml
    assert_equal $status 0 || fail "${lines[@]}"
    
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    local expected='ecs-deploy -c cls01 -n hello-world-dev --tag-only bb255ec-93 -i ignored-image --task-definition-file /tmp/task-definition\.json.\w*'
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'install - task definition, with values' {
    run ./yoke install -c any -s any -t any -w test/samples/hello-world/deployment -f values-dev.yaml
    assert_equal $status 0 || fail "${lines[@]}"
    
    local task_definition="$( cat $YOKE_FAKES_LOGGING | grep -o '/tmp/task-definition\.json.\w*' )"
    local family="$( cat $task_definition | jq | grep family | cut -d \" -f 4)"
    assert_equal "$family" "hello-world-dev"
}

@test 'install - task definition, without values' {
    run ./yoke install -c any -s any -t bb255ec-93 -w test/deployments/task_definition_template_only
    assert_equal $status 0 || fail "${lines[@]}"

    local commands="$( cat $YOKE_FAKES_LOGGING )"
    local expected='--tag-only bb255ec-93 -i ignored-image --task-definition-file /tmp/task-definition\.json.\w*'
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'install - task definition, on failure' {
    run ./yoke install -c any -s any -t any -w test/deployments/failing -d
    assert_equal $status 1 || fail "${lines[@]}"
    
    local expected="cannot prepare task-definition"
    local output=$( last_execution_output )
    [[ $output =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$output\""
}

@test 'install - task set, without values' {
    run ./yoke install -c any -s any -t bb255ec-93 -w test/deployments/task_set_template_only
    assert_equal $status 0 || fail "$commands"

    local commands="$( cat $YOKE_FAKES_LOGGING )"    
    local expected='--task-definition-file .*task-definition\.json.* --task-set-file .*task-set\.json.*'
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'install - task set, with values' {
    run ./yoke install -c any -s any -t bb255ec-93 -w test/deployments/task_set_template_with_arguments -f values-dev.yaml
    assert_equal $status 0 || fail "${lines[@]}"
    
    local commands="$( cat $YOKE_FAKES_LOGGING )"    
    local task_set="$( echo $commands | grep -o '/tmp/task-set\.json.\w*' )"
    local securityGroup="$( cat $task_set | jq -cr '.taskSet.networkConfiguration.awsvpcConfiguration.securityGroups[0]' )"
    assert_equal "$securityGroup" "sg-abcdefghil1234567"
}

@test 'update - task set, default confirmation values' {
    run ./yoke update -c any -s any -t bb255ec-93 -w test/deployments/task_set_template_only
    assert_equal $status 0 || fail "${lines[@]}"

    local commands="$( cat $YOKE_FAKES_LOGGING )"
    local expected='--canary-confirmation wait_timeout'
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'update - task set, custom confirmation' {
    run ./yoke update -c any -s any -t bb255ec-93 -w test/deployments/task_set_with_confirmation
    assert_equal $status 0 || fail "${lines[@]}"

    local commands="$( cat $YOKE_FAKES_LOGGING )"
    local expected='--canary-confirmation /tmp/confirm.sh.\w*'
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'install - task set, default confirmation values' {
    run ./yoke install -c any -s any -t bb255ec-93 -w test/deployments/task_set_template_only
    assert_equal $status 0 || fail "${lines[@]}"

    local commands="$( cat $YOKE_FAKES_LOGGING )"
    local expected='--canary-confirmation wait_timeout'
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'install - task set, custom confirmation' {
    run ./yoke install -c any -s any -t bb255ec-93 -w test/deployments/task_set_with_confirmation
    assert_equal $status 0 || fail "${lines[@]}"

    local commands="$( cat $YOKE_FAKES_LOGGING )"
    local expected='--canary-confirmation /tmp/confirm.sh.\w*'
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'prune old task definitions' {
    run ./yoke update -c any -s any -t any --prune 5
    
    local expected='--max-definitions 5'
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'default timeout' {
    run ./yoke update -c any -s any -t any
    
    local expected='--timeout 300'
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'given timeout' {
    run ./yoke update -c any -s any -t any --timeout 60
    
    local expected='--timeout 60'
    local commands="$( cat $YOKE_FAKES_LOGGING )"
    [[ $commands =~ $expected ]] || fail "not matching. expected: \"$expected\", actual: \"$commands\""
}

@test 'dry-run' {
    run ./yoke update -c any -s any -t any --dry-run
    assert_equal $status 0 || fail "${lines[@]}"
    
    [[ ! -r "$YOKE_FAKES_LOGGING" ]] || fail "not expected to exist $YOKE_FAKES_LOGGING. content: \"$( cat $YOKE_FAKES_LOGGING )\""
}

@test 'shell running in working directory' {
    run ./yoke install -c any -s any -t 12345 -w test/deployments/shell_working_directory
    assert_equal $status 0 || fail "${lines[@]}"
    
    local task_definition="$( cat $YOKE_FAKES_LOGGING | grep -o '/tmp/task-definition\.json.\w*' )"
    local family="$( cat $task_definition | jq -r ".taskDefinition.family" )"
    assert_equal "$family" "Hello"
}