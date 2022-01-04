#!/usr/bin/env bash

# force updating dependencies, to ensure stdout will be clean
./lib/update && ./yoke --version
./lib/bats/bin/bats test