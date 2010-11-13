This is Gundo's test suite.  In case you didn't know, unit testing vim plugins
is a horrible experience.

Gundo bundles Luc Hermitte's [UT][] framework to make the process less painful.

[UT]: http://code.google.com/p/lh-vim/wiki/UT

To run a test, `cd` into the `tests` directory and use:

    ./run-tests.sh [[some-test.vim] ...]

The script will run the console vim command with its own vimrc and .vim
directory, so none of your other plugins should interfere. The result of the
tests will be shown in the quickfix window of this vim instance.

The `q` key will be remapped to perform `:qa!` so you can close everything
quickly if it all looks good.

The `run-tests.sh` script is still a work in progress.  I need to figure out
a good way of collecting results.  Suggestions and/or patches are very welcome.
