#!/usr/bin/env bash

# force updating dependencies, to ensure stdout will be clean
./lib/update
./lib/bats/bin/bats test