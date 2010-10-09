Gundo.vim is Vim plugin to visualize your Vim undo tree.

Current status: Alpha. It will probably eat your data. Be careful.
==================================================================


Requirements
------------

* Vim 7.3+
* Python support for Vim.

Installation
------------

Use [Pathogen][]. Don't use pathogen? Start.

Add a mapping to your `~/.vimrc` (change the key to suit your taste):

    nnoremap <F5> :GundoToggle<CR>

[Pathogen]: http://www.vim.org/scripts/script.php?script_id=2332

Usage
-----

When you're editing a file you can bring up the undo graph with `<F5>` (or
whatever key you mapped it to).

Press `<F5>` again to close the undo tree and return to your file.

Use `j` and `k` to move up and down the tree. The preview pane will update with
a diff of the change made by the undo state you're currently on.

Press return to revert the file's contents to that undo state and return to the
file.
