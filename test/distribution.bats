load '../lib/bin/bats-support/load'
load '../lib/bin/bats-assert/load'

setup() {
    export PATH="$( realpath test/bin/helpers ):$( realpath test/fake/platform ):$( realpath test/fake/lib ):$PATH"
    export YOKE_DIST_DIR="$BATS_TMPDIR/yoke/$RANDOM"
    mkdir -p $YOKE_DIST_DIR
}

teardown() {
    rm -rf $YOKE_DIST_DIR
}

@test 'dist, archive created' {
    DIST_DIR=$YOKE_DIST_DIR run ./dist.sh
    
    assert_equal $status 0
    [[ -f $YOKE_DIST_DIR/yoke.bin ]] || fail "distribution archive expected to be created in $YOKE_DIST_DIR"
}
