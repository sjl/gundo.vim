<a href="http://flattr.com/thing/74149/Gundo-vim" target="_blank">
<img src="http://api.flattr.com/button/button-compact-static-100x17.png" alt="Flattr this" title="Flattr this" border="0" /></a>

Gundo.vim is Vim plugin to visualize your Vim undo tree.

Current status: Beta. It might eat your data. Be careful.
=========================================================

Preview
-------

Screenshot:

<a href="http://www.flickr.com/photos/sjl7678/5093114605/" title="gundo by stevelosh, on Flickr"><img src="http://farm5.static.flickr.com/4113/5093114605_ebc46d6494.jpg" width="487" height="500" alt="gundo" /></a>

Screencast: [http://screenr.com/M9l](http://screenr.com/M9l)


Requirements
------------

* Vim 7.3+
* Python support for Vim
* Python 2.4+

Installation
------------

Use [Pathogen][]. Don't use pathogen? Start.

Add a mapping to your `~/.vimrc` (change the key to suit your taste):

    nnoremap <F5> :GundoToggle<CR>

[Pathogen]: http://www.vim.org/scripts/script.php?script_id=2332

Usage
-----

Run `:help gundo` for the full docs. Here's the in-a-nutshell version.

When you're editing a file you can bring up the undo graph for that file with
`<F5>` (or whatever key you mapped it to).

Press `<F5>` again to close the undo graph and return to your file.

Use `j` and `k` to move up and down the graph. The preview pane will update with
a diff of the change made by the undo state you're currently on.

Press return to revert the file's contents to that undo state and return to the
file.
