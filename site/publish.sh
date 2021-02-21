#!/usr/bin/env bash

set -euo pipefail

hg -R ~/src/docs.stevelosh.com pull -u
rsync --delete -az . ~/src/docs.stevelosh.com/gundo.vim
hg -R ~/src/docs.stevelosh.com commit -Am 'gundo.vim: Update documentation.'
hg -R ~/src/docs.stevelosh.com push
