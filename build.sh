#!/usr/bin/env bash

# force updating dependencies, to ensure stdout will be clean
./bin/install && ./yoke --version
./lib/bats/bin/bats test