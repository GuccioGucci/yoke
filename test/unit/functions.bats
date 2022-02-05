load '../../lib/bin/bats-support/load'
load '../../lib/bin/bats-assert/load'

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