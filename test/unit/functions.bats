load '../../lib/bin/bats-support/load'
load '../../lib/bin/bats-assert/load'

setup() {
    export YOKE_TMP="$BATS_TMPDIR/yoke/$RANDOM"
    mkdir -p "$YOKE_TMP"
}

teardown() {
    rm -rf "$YOKE_TMP"
}

@test 'resource, set' {
    source yoke
    
    resource_set bar LIFECYCLE_FOO
    [[ "$LIFECYCLE_FOO" == "bar" ]] || fail "expected: bar, actual: $LIFECYCLE_FOO"
}

@test 'resource, get' {
    source yoke
    
    LIFECYCLE_FOO="bar"
    local actual=$(resource_get LIFECYCLE_FOO )
    [[ "$actual" == "bar" ]] || fail "expected: bar, actual: $actual"
}

@test 'on post-deploy, skip' {
    source yoke

    LIFECYCLE_POST=none

    result="$( on_post_deploy )"
    [[ -z $result ]] || fail "result: $result"
}

@test 'on post-deploy, success' {
    source yoke

    LIFECYCLE_POST=$YOKE_TMP/shell.sh    
    echo "echo Hello!" > $LIFECYCLE_POST ; chmod +x $LIFECYCLE_POST

    result="$( on_post_deploy )"
    [[ $result =~ "Hello" ]] || fail "result: $result"
}