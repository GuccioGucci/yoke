load '../lib/bin/bats-support/load'
load '../lib/bin/bats-assert/load'

setup() {
    export PATH="$( realpath test/bin/helpers ):$( realpath test/fake/platform ):$( realpath test/fake/lib ):$PATH"
    export YOKE_FAKES_LOGGING="$BATS_TMPDIR/yoke/$RANDOM/commands.log"
    mkdir -p "$( dirname $YOKE_FAKES_LOGGING )"
}

teardown() {
    rm -rf "$( dirname $YOKE_FAKES_LOGGING )"
}

@test 'help' {
    run ./yoke -h
    assert_equal $status 0
    assert_equal "${lines[0]}" "usage: ./yoke command [parameters]"
}

@test 'help by default on empty' {
    run ./yoke
    assert_equal $status 1
    assert_equal "${lines[0]}" "usage: ./yoke command [parameters]"
}

@test 'help by default on wrong parameter' {
    run ./yoke --hello
    assert_equal $status 1
    assert_equal "${lines[0]}" "usage: ./yoke command [parameters]"
}

@test 'help by default on wrong command' {
    run ./yoke hello
    assert_equal $status 1
    assert_equal "${lines[0]}" "unsupported command"
    assert_equal "${lines[1]}" "usage: ./yoke command [parameters]"
}

@test 'help by default on missing update parameters' {
    run ./yoke update
    assert_equal $status 1
    [[ ${lines[0]} =~ provided ]] || fail "(not matched) $output"
    assert_equal "${lines[1]}" "usage: ./yoke command [parameters]"
}

@test 'help by default on missing install parameters' {
    run ./yoke install
    assert_equal $status 1
    [[ ${lines[0]} =~ provided ]] || fail "(not matched) $output"
    assert_equal "${lines[1]}" "usage: ./yoke command [parameters]"
}

@test 'version' {
    run ./yoke -v
    assert_equal $status 0
    [[ $output =~ '(templating) gucci' ]] && [[ $output =~ '(deployment) ecs-deploy' ]] || fail "$output"
}