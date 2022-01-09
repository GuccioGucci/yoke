#!/usr/bin/env bash

# force updating dependencies (app, test and dist), to ensure stdout will be clean
./bin/install --all && ./yoke --version
./lib/bin/bats test