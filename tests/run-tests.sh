#!/usr/bin/env bash

set -e

vim -u vimrc_test -c ":UTRun $1"
