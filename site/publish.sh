#!/usr/bin/env bash

hg -R ~/src/sjl.bitbucket.org pull -u
rsync --delete -az . ~/src/sjl.bitbucket.org/gundo.vim
hg -R ~/src/sjl.bitbucket.org commit -Am 'gundo.vim: Update documentation.'
hg -R ~/src/sjl.bitbucket.org push
