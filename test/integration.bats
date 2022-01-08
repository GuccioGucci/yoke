load '../lib/bin/bats-support/load'
load '../lib/bin/bats-assert/load'

setup() {
    export PATH="$( realpath test/fake/platform ):$PATH"
    export YOKE_FAKES_LOGGING="$BATS_TMPDIR/yoke/$RANDOM/commands.log"
    mkdir -p "$( dirname $YOKE_FAKES_LOGGING )"
}

teardown() {
    rm -rf "$( dirname $YOKE_FAKES_LOGGING )"
}

last_execution_output() {
    printf '%s\n' "${lines[@]}"
}

assert_lines_contains() {
  local pattern=$1
  local matched="false"
  for ((i = 0; i < ${#lines[@]}; i++)); do
      if [[ $( echo "${lines[$i]}" | grep "$pattern" ) ]]; then
        matched="true"
        break
      fi
  done
  [[ "$matched" == "true" ]] || fail "$matched not found in: ${lines[@]}"
}

@test 'integration - hello-world install tag' {
    run ./yoke install -c cls01 -s hello-world-dev -w test/samples/hello-world/deployment -f values-dev.yaml -t 6e973c2-116 --timeout 5

    local commands="$( cat $YOKE_FAKES_LOGGING )"
    local output=$( last_execution_output )
    
    [[ $status -eq 0 ]] || fail "($status) COMMAND: $commands, OUTPUT: $output"
    assert_lines_contains "^Service deployment successful."
}