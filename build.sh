#!/usr/bin/env bash

# force updating dependencies (test and app), to ensure stdout will be clean
./bin/install --test && ./yoke --version
./lib/bin/bats test