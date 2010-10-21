" ============================================================================
" File:        gundo.vim
" Description: vim global plugin to visualize your undo tree
" Maintainer:  Steve Losh <steve@stevelosh.com>
" License:     GPLv2+ -- look it up.
" Notes:       Much of this code was thiefed from Mercurial, and the rest was
"              heavily inspired by scratch.vim and histwin.vim.
"
" ============================================================================


"{{{ Init

if !exists('g:gundo_debug') && (exists('loaded_gundo') || &cp)"{{{
    finish
endif
let loaded_gundo = 1"}}}

if v:version < '703'"{{{
    echo  "Gundo requires Vim 7.3+"
    finish
endif"}}}

if has('python')"{{{
    let s:has_supported_python = 1

python << ENDPYTHON
import sys
import vim
if sys.version_info[:2] < (2, 4):
    vim.command('let s:has_supported_python = 0')
ENDPYTHON

    " Python version is too old
    if !s:has_supported_python
        echo  "Gundo requires that Vim be compiled with Python 2.4+"
        finish
    endif
else
    " no Python support
    echo  "Gundo requires that Vim be compiled with Python 2.4+"
    finish
endif"}}}

if !exists('g:gundo_width')"{{{
    let g:gundo_width = 45
endif"}}}
if !exists('g:gundo_preview_height')"{{{
    let g:gundo_preview_height = 15
endif"}}}
if !exists('g:gundo_right')"{{{
    let g:gundo_right = 0
endif"}}}

"}}}

"{{{ Mercurial's graphlog code
python << ENDPYTHON
def asciiedges(seen, rev, parents):
    """adds edge info to changelog DAG walk suitable for ascii()"""
    if rev not in seen:
        seen.append(rev)
    nodeidx = seen.index(rev)

    knownparents = []
    newparents = []
    for parent in parents:
        if parent in seen:
            knownparents.append(parent)
        else:
            newparents.append(parent)

    ncols = len(seen)
    seen[nodeidx:nodeidx + 1] = newparents
    edges = [(nodeidx, seen.index(p)) for p in knownparents]

    if len(newparents) > 0:
        edges.append((nodeidx, nodeidx))
    if len(newparents) > 1:
        edges.append((nodeidx, nodeidx + 1))

    nmorecols = len(seen) - ncols
    return nodeidx, edges, ncols, nmorecols

def get_nodeline_edges_tail(
        node_index, p_node_index, n_columns, n_columns_diff, p_diff, fix_tail):
    if fix_tail and n_columns_diff == p_diff and n_columns_diff != 0:
        # Still going in the same non-vertical direction.
        if n_columns_diff == -1:
            start = max(node_index + 1, p_node_index)
            tail = ["|", " "] * (start - node_index - 1)
            tail.extend(["/", " "] * (n_columns - start))
            return tail
        else:
            return ["\\", " "] * (n_columns - node_index - 1)
    else:
        return ["|", " "] * (n_columns - node_index - 1)

def draw_edges(edges, nodeline, interline):
    for (start, end) in edges:
        if start == end + 1:
            interline[2 * end + 1] = "/"
        elif start == end - 1:
            interline[2 * start + 1] = "\\"
        elif start == end:
            interline[2 * start] = "|"
        else:
            nodeline[2 * end] = "+"
            if start > end:
                (start, end) = (end, start)
            for i in range(2 * start + 1, 2 * end):
                if nodeline[i] != "+":
                    nodeline[i] = "-"

def ascii(buf, state, type, char, text, coldata):
    """prints an ASCII graph of the DAG

    takes the following arguments (one call per node in the graph):

      - buffer to write to
      - Somewhere to keep the needed state in (init to asciistate())
      - Column of the current node in the set of ongoing edges.
      - Type indicator of node data == ASCIIDATA.
      - Payload: (char, lines):
        - Character to use as node's symbol.
        - List of lines to display as the node's text.
      - Edges; a list of (col, next_col) indicating the edges between
        the current node and its parents.
      - Number of columns (ongoing edges) in the current revision.
      - The difference between the number of columns (ongoing edges)
        in the next revision and the number of columns (ongoing edges)
        in the current revision. That is: -1 means one column removed;
        0 means no columns added or removed; 1 means one column added.
    """

    idx, edges, ncols, coldiff = coldata
    assert -2 < coldiff < 2
    if coldiff == -1:
        # Transform
        #
        #     | | |        | | |
        #     o | |  into  o---+
        #     |X /         |/ /
        #     | |          | |
        fix_long_right_edges(edges)

    # add_padding_line says whether to rewrite
    #
    #     | | | |        | | | |
    #     | o---+  into  | o---+
    #     |  / /         |   | |  # <--- padding line
    #     o | |          |  / /
    #                    o | |
    add_padding_line = (len(text) > 2 and coldiff == -1 and
                        [x for (x, y) in edges if x + 1 < y])

    # fix_nodeline_tail says whether to rewrite
    #
    #     | | o | |        | | o | |
    #     | | |/ /         | | |/ /
    #     | o | |    into  | o / /   # <--- fixed nodeline tail
    #     | |/ /           | |/ /
    #     o | |            o | |
    fix_nodeline_tail = len(text) <= 2 and not add_padding_line

    # nodeline is the line containing the node character (typically o)
    nodeline = ["|", " "] * idx
    nodeline.extend([char, " "])

    nodeline.extend(
        get_nodeline_edges_tail(idx, state[1], ncols, coldiff,
                                state[0], fix_nodeline_tail))

    # shift_interline is the line containing the non-vertical
    # edges between this entry and the next
    shift_interline = ["|", " "] * idx
    if coldiff == -1:
        n_spaces = 1
        edge_ch = "/"
    elif coldiff == 0:
        n_spaces = 2
        edge_ch = "|"
    else:
        n_spaces = 3
        edge_ch = "\\"
    shift_interline.extend(n_spaces * [" "])
    shift_interline.extend([edge_ch, " "] * (ncols - idx - 1))

    # draw edges from the current node to its parents
    draw_edges(edges, nodeline, shift_interline)

    # lines is the list of all graph lines to print
    lines = [nodeline]
    if add_padding_line:
        lines.append(get_padding_line(idx, ncols, edges))
    lines.append(shift_interline)

    # make sure that there are as many graph lines as there are
    # log strings
    while len(text) < len(lines):
        text.append("")
    if len(lines) < len(text):
        extra_interline = ["|", " "] * (ncols + coldiff)
        while len(lines) < len(text):
            lines.append(extra_interline)

    # print lines
    indentation_level = max(ncols, ncols + coldiff)
    for (line, logstr) in zip(lines, text):
        ln = "%-*s %s" % (2 * indentation_level, "".join(line), logstr)
        buf.write(ln.rstrip() + '\n')

    # ... and start over
    state[0] = coldiff
    state[1] = idx

def fix_long_right_edges(edges):
    for (i, (start, end)) in enumerate(edges):
        if end > start:
            edges[i] = (start, end + 1)

def ascii(buf, state, type, char, text, coldata):
    """prints an ASCII graph of the DAG

    takes the following arguments (one call per node in the graph):

      - Somewhere to keep the needed state in (init to asciistate())
      - Column of the current node in the set of ongoing edges.
      - Type indicator of node data == ASCIIDATA.
      - Payload: (char, lines):
        - Character to use as node's symbol.
        - List of lines to display as the node's text.
      - Edges; a list of (col, next_col) indicating the edges between
        the current node and its parents.
      - Number of columns (ongoing edges) in the current revision.
      - The difference between the number of columns (ongoing edges)
        in the next revision and the number of columns (ongoing edges)
        in the current revision. That is: -1 means one column removed;
        0 means no columns added or removed; 1 means one column added.
    """

    idx, edges, ncols, coldiff = coldata
    assert -2 < coldiff < 2
    if coldiff == -1:
        # Transform
        #
        #     | | |        | | |
        #     o | |  into  o---+
        #     |X /         |/ /
        #     | |          | |
        fix_long_right_edges(edges)

    # add_padding_line says whether to rewrite
    #
    #     | | | |        | | | |
    #     | o---+  into  | o---+
    #     |  / /         |   | |  # <--- padding line
    #     o | |          |  / /
    #                    o | |
    add_padding_line = (len(text) > 2 and coldiff == -1 and
                        [x for (x, y) in edges if x + 1 < y])

    # fix_nodeline_tail says whether to rewrite
    #
    #     | | o | |        | | o | |
    #     | | |/ /         | | |/ /
    #     | o | |    into  | o / /   # <--- fixed nodeline tail
    #     | |/ /           | |/ /
    #     o | |            o | |
    fix_nodeline_tail = len(text) <= 2 and not add_padding_line

    # nodeline is the line containing the node character (typically o)
    nodeline = ["|", " "] * idx
    nodeline.extend([char, " "])

    nodeline.extend(
        get_nodeline_edges_tail(idx, state[1], ncols, coldiff,
                                state[0], fix_nodeline_tail))

    # shift_interline is the line containing the non-vertical
    # edges between this entry and the next
    shift_interline = ["|", " "] * idx
    if coldiff == -1:
        n_spaces = 1
        edge_ch = "/"
    elif coldiff == 0:
        n_spaces = 2
        edge_ch = "|"
    else:
        n_spaces = 3
        edge_ch = "\\"
    shift_interline.extend(n_spaces * [" "])
    shift_interline.extend([edge_ch, " "] * (ncols - idx - 1))

    # draw edges from the current node to its parents
    draw_edges(edges, nodeline, shift_interline)

    # lines is the list of all graph lines to print
    lines = [nodeline]
    if add_padding_line:
        lines.append(get_padding_line(idx, ncols, edges))
    lines.append(shift_interline)

    # make sure that there are as many graph lines as there are
    # log strings
    while len(text) < len(lines):
        text.append("")
    if len(lines) < len(text):
        extra_interline = ["|", " "] * (ncols + coldiff)
        while len(lines) < len(text):
            lines.append(extra_interline)

    # print lines
    indentation_level = max(ncols, ncols + coldiff)
    for (line, logstr) in zip(lines, text):
        ln = "%-*s %s" % (2 * indentation_level, "".join(line), logstr)
        buf.write(ln.rstrip() + '\n')

    # ... and start over
    state[0] = coldiff
    state[1] = idx

def generate(dag, edgefn, current):
    seen, state = [], [0, 0]
    buf = Buffer()
    for node, parents in list(dag):
        if node.time:
            age_label = age(int(node.time))
        else:
            age_label = 'Original'
        line = '[%s] %s' % (node.n, age_label)
        if node.n == current:
            char = '@'
        else:
            char = 'o'
        ascii(buf, state, 'C', char, [line], edgefn(seen, node, parents))
    return buf.b
ENDPYTHON
"}}}

"{{{ Mercurial age function
python << ENDPYTHON
import time

agescales = [("year", 3600 * 24 * 365),
             ("month", 3600 * 24 * 30),
             ("week", 3600 * 24 * 7),
             ("day", 3600 * 24),
             ("hour", 3600),
             ("minute", 60),
             ("second", 1)]

def age(ts):
    '''turn a timestamp into an age string.'''

    def plural(t, c):
        if c == 1:
            return t
        return t + "s"
    def fmt(t, c):
        return "%d %s" % (c, plural(t, c))

    now = time.time()
    then = ts
    if then > now:
        return 'in the future'

    delta = max(1, int(now - then))
    if delta > agescales[0][1] * 2:
        return time.strftime('%Y-%m-%d', time.gmtime(float(ts)))

    for t, s in agescales:
        n = delta // s
        if n >= 2 or s == 1:
            return '%s ago' % fmt(t, n)
ENDPYTHON
"}}}

"{{{ Python Vim utility functions
python << ENDPYTHON
import vim

normal = lambda s: vim.command('normal %s' % s)

def _goto_window_for_buffer(b):
    w = vim.eval('bufwinnr(%d)' % int(b))
    vim.command('%dwincmd w' % int(w))

def _goto_window_for_buffer_name(bn):
    b = vim.eval('bufnr("%s")' % bn)
    _goto_window_for_buffer(b)

def _undo_to(n):
    n = int(n)
    if n == 0:
        vim.command('silent earlier 999999999d')
    else:
        vim.command('silent undo %d' % n)


INLINE_HELP = '''\
" Gundo for %s [%d]
" j/k  - move between undo states
" <cr> - revert to that state

'''
ENDPYTHON
"}}}

"{{{ Python undo tree data structures and functions
python << ENDPYTHON
import itertools

class Buffer(object):
    def __init__(self):
        self.b = ''

    def write(self, s):
        self.b += s

class Node(object):
    def __init__(self, n, parent, time, curhead):
        self.n = int(n)
        self.parent = parent
        self.children = []
        self.curhead = curhead
        self.time = time

def _make_nodes(alts, nodes, parent=None):
    p = parent

    for alt in alts:
        curhead = 'curhead' in alt
        node = Node(n=alt['seq'], parent=p, time=alt['time'], curhead=curhead)
        nodes.append(node)
        if alt.get('alt'):
            _make_nodes(alt['alt'], nodes, p)
        p = node

def make_nodes():
    ut = vim.eval('undotree()')
    entries = ut['entries']

    root = Node(0, None, False, 0)
    nodes = []
    _make_nodes(entries, nodes, root)
    nodes.append(root)
    nmap = dict((node.n, node) for node in nodes)
    return nodes, nmap

def changenr(nodes):
    # TODO: This seems to sometimes be wrong right after you open a file...
    _curhead_l = list(itertools.dropwhile(lambda n: not n.curhead, nodes))
    if _curhead_l:
        current = _curhead_l[0].parent.n
    else:
        current = int(vim.eval('changenr()'))
    return current
ENDPYTHON
"}}}

"{{{ Gundo buffer settings

function! s:GundoMapGraph()"{{{
    nnoremap <script> <silent> <buffer> <CR>          :call <sid>GundoRevert()<CR>
    nnoremap <script> <silent> <buffer> j             :call <sid>GundoMove(1)<CR>
    nnoremap <script> <silent> <buffer> k             :call <sid>GundoMove(-1)<CR>
    nnoremap <script> <silent> <buffer> gg            gg:call <sid>GundoMove(1)<CR>
    nnoremap <script> <silent> <buffer> P             :call <sid>GundoPlayTo()<CR>
    nnoremap <script> <silent> <buffer> q             :call <sid>GundoClose()<CR>
    cabbrev  <script> <silent> <buffer> q             call <sid>GundoClose()
    cabbrev  <script> <silent> <buffer> quit          call <sid>GundoClose()
    nnoremap <script> <silent> <buffer> <2-LeftMouse> :call <sid>GundoMouseDoubleClick()<CR>
endfunction"}}}

function! s:GundoMapPreview()"{{{
    nnoremap <script> <silent> <buffer> q     :call <sid>GundoClose()<CR>
    cabbrev  <script> <silent> <buffer> q     call <sid>GundoClose()
    cabbrev  <script> <silent> <buffer> quit  call <sid>GundoClose()
endfunction"}}}

function! s:GundoSettingsGraph()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=gundo
    setlocal nolist
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    call s:GundoSyntaxGraph()
    call s:GundoMapGraph()
endfunction"}}}

function! s:GundoSettingsPreview()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=diff
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    setlocal foldlevel=20
    call s:GundoMapPreview()
endfunction"}}}

function! s:GundoSyntaxGraph()"{{{
    let b:current_syntax = 'gundo'

    syn match GundoCurrentLocation '@'
    syn match GundoHelp '\v^".*$'
    syn match GundoNumberField '\v\[[0-9]+\]'
    syn match GundoNumber '\v[0-9]+' contained containedin=GundoNumberField

    hi def link GundoCurrentLocation Keyword
    hi def link GundoHelp Comment
    hi def link GundoNumberField Comment
    hi def link GundoNumber Identifier
endfunction"}}}

"}}}

"{{{ Buffer/window management

function! s:GundoResizeBuffers(backto)"{{{
    exe bufwinnr(bufnr('__Gundo__')) . "wincmd w"
    exe "vertical resize " . g:gundo_width

    exe bufwinnr(bufnr('__Gundo_Preview__')) . "wincmd w"
    exe "resize " . g:gundo_preview_height

    exe a:backto . "wincmd w"
endfunction"}}}

function! s:GundoOpenGraph()"{{{
    let existing_gundo_buffer = bufnr("__Gundo__")

    if existing_gundo_buffer == -1
        exe bufwinnr(bufnr('__Gundo_Preview__')) . "wincmd w"
        exe "new __Gundo__"
        call s:GundoResizeBuffers(winnr())
    else
        let existing_gundo_window = bufwinnr(existing_gundo_buffer)

        if existing_gundo_window != -1
            if winnr() != existing_gundo_window
                exe existing_gundo_window . "wincmd w"
            endif
        else
            exe bufwinnr(bufnr('__Gundo_Preview__')) . "wincmd w"
            exe "split +buffer" . existing_gundo_buffer
            call s:GundoResizeBuffers(winnr())
        endif
    endif
endfunction"}}}

function! s:GundoOpenPreview()"{{{
    let existing_preview_buffer = bufnr("__Gundo_Preview__")

    if existing_preview_buffer == -1
        exe "vnew __Gundo_Preview__"

        if g:gundo_right
            wincmd L
        else
            wincmd H
        endif
    else
        let existing_preview_window = bufwinnr(existing_preview_buffer)

        if existing_preview_window != -1
            if winnr() != existing_preview_window
                exe existing_preview_window . "wincmd w"
            endif
        else
            exe "vsplit +buffer" . existing_preview_buffer

            if g:gundo_right
                wincmd L
            else
                wincmd H
            endif
        endif
    endif
endfunction"}}}

function! s:GundoClose()"{{{
        if bufwinnr(bufnr('__Gundo__')) != -1
            exe bufwinnr(bufnr('__Gundo__')) . "wincmd w"
            quit
        endif

        if bufwinnr(bufnr('__Gundo_Preview__')) != -1
            exe bufwinnr(bufnr('__Gundo_Preview__')) . "wincmd w"
            quit
        endif

        exe bufwinnr(g:gundo_target_n) . "wincmd w"
endfunction"}}}

function! s:GundoToggle()"{{{
    if expand('%') == "__Gundo__"
        call s:GundoClose()
    else
        if expand('%') != "__Gundo_Preview__"
            " Record the previous buffer number.
            "
            " This sucks because we're not getting the window number, and there
            " may be more than one window viewing the same buffer, so we might
            " go back to the wrong one.
            "
            " Unfortunately window numbers change as we open more windows.
            "
            " TODO: Figure out how to fix this.
            let g:gundo_target_n = bufnr('')
            let g:gundo_target_f = @%
        endif

        call s:GundoOpenPreview()
        exe bufwinnr(g:gundo_target_n) . "wincmd w"
        GundoRender

        " TODO: Move these lines into RenderPreview
        let target_line = matchstr(getline("."), '\v\[[0-9]+\]')
        let target_num = matchstr(target_line, '\v[0-9]+')
        call s:GundoRenderPreview(target_num)
    endif
endfunction"}}}

"}}}

"{{{ Mouse handling

function! s:GundoMouseDoubleClick()"{{{
    let start_line = getline('.')

    if stridx(start_line, '[') == -1
        return
    else
        call s:GundoRevert()
    endif
endfunction"}}}
 
"}}}

"{{{ Movement

function! s:GundoMove(direction)"{{{
    let start_line = getline('.')

    " If we're in between two nodes we move by one to get back on track.
    if stridx(start_line, '[') == -1
        let distance = 1
    else
        let distance = 2
    endif

    let target_n = line('.') + (distance * a:direction)

    " Bound the movement to the graph.
    if target_n <= 4
        call cursor(5, 0)
    else
        call cursor(target_n, 0)
    endif

    let line = getline('.')

    " Move to the node, whether it's an @ or an o
    let idx1 = stridx(line, '@')
    let idx2 = stridx(line, 'o')
    if idx1 != -1
        call cursor(0, idx1 + 1)
    else
        call cursor(0, idx2 + 1)
    endif

    let target_line = matchstr(getline("."), '\v\[[0-9]+\]')
    let target_num = matchstr(target_line, '\v[0-9]+')
    call s:GundoRenderPreview(target_num)
endfunction"}}}

"}}}

"{{{ Rendering

function! s:GundoRenderGraph()"{{{
python << ENDPYTHON
def GundoRenderGraph():
    nodes, nmap = make_nodes()

    for node in nodes:
        node.children = [n for n in nodes if n.parent == node]

    def walk_nodes(nodes):
        for node in nodes:
            if node.parent:
                yield (node, [node.parent])
            else:
                yield (node, [])

    dag = sorted(nodes, key=lambda n: int(n.n), reverse=True)
    current = changenr(nodes)

    result = generate(walk_nodes(dag), asciiedges, current).rstrip().splitlines()
    result = [' ' + l for l in result]

    target = (vim.eval('g:gundo_target_f'), int(vim.eval('g:gundo_target_n')))
    header = (INLINE_HELP % target).splitlines()

    vim.command('GundoOpenGraph')
    vim.command('setlocal modifiable')
    vim.current.buffer[:] = (header + result)
    vim.command('setlocal nomodifiable')

    i = 1
    for line in result:
        try:
            line.split('[')[0].index('@')
            i += 1
            break
        except ValueError:
            pass
        i += 1
    vim.command('%d' % (i+len(header)-1))

GundoRenderGraph()
ENDPYTHON
endfunction"}}}

function! s:GundoRenderPreview(target)"{{{
python << ENDPYTHON
import difflib

def _fmt_time(t):
    return time.strftime('%Y-%m-%d %I:%M:%S %p', time.localtime(float(t)))

def _output_preview_text(lines):
    _goto_window_for_buffer_name('__Gundo_Preview__')
    vim.command('setlocal modifiable')
    vim.current.buffer[:] = lines
    vim.command('setlocal nomodifiable')

def _generate_preview_diff(current, node_before, node_after):
    _goto_window_for_buffer(vim.eval('g:gundo_target_n'))

    if not node_after.n:    # we're at the original file
        before_lines = []

        _undo_to(0)
        after_lines = vim.current.buffer[:]

        before_name = 'n/a'
        before_time = ''
        after_name = 'Original'
        after_time = ''
    elif not node_before.n: # we're at a pseudo-root state
        _undo_to(0)
        before_lines = vim.current.buffer[:]

        _undo_to(node_after.n)
        after_lines = vim.current.buffer[:]

        before_name = 'Original'
        before_time = ''
        after_name = node_after.n
        after_time = _fmt_time(node_after.time)
    else:
        _undo_to(node_before.n)
        before_lines = vim.current.buffer[:]

        _undo_to(node_after.n)
        after_lines = vim.current.buffer[:]

        before_name = node_before.n
        before_time = _fmt_time(node_before.time)
        after_name = node_after.n
        after_time = _fmt_time(node_after.time)

    _undo_to(current)

    return list(difflib.unified_diff(before_lines, after_lines,
                                     before_name, after_name,
                                     before_time, after_time))

def GundoRenderPreview():
    target_n = vim.eval('a:target')

    # Check that there's an undo state. There may not be if we're talking about
    # a buffer with no changes yet.
    if target_n == None:
        _goto_window_for_buffer_name('__Gundo__')
        return
    else:
        target_n = int(vim.eval('a:target'))

    _goto_window_for_buffer(vim.eval('g:gundo_target_n'))

    nodes, nmap = make_nodes()
    current = changenr(nodes)

    node_after = nmap[target_n]
    node_before = node_after.parent

    _output_preview_text(_generate_preview_diff(current, node_before, node_after))

    _goto_window_for_buffer_name('__Gundo__')

GundoRenderPreview()
ENDPYTHON
endfunction"}}}

"}}}

"{{{ Undo/redo commands

function! s:GundoRevert()"{{{
    let target_line = matchstr(getline("."), '\v\[[0-9]+\]')
    let target_num = matchstr(target_line, '\v[0-9]+')
    let back = bufwinnr(g:gundo_target_n)
    exe back . "wincmd w"
python << ENDPYTHON
_undo_to(vim.eval('target_num'))
ENDPYTHON
    GundoRenderGraph
    exe back . "wincmd w"
endfunction"}}}

function! s:GundoPlayTo()"{{{
    let target_line = matchstr(getline("."), '\v\[[0-9]+\]')
    let target_num = matchstr(target_line, '\v[0-9]+')
    let back = bufwinnr(g:gundo_target_n)
    exe back . "wincmd w"
    normal zR

python << ENDPYTHON
def GundoPlayTo():
    nodes, nmap = make_nodes()

    start = nmap[changenr(nodes)]
    end = nmap[int(vim.eval('target_num'))]

    def _walk_branch(origin, dest):
        rev = origin.n < dest.n

        nodes = []
        if origin.n > dest.n:
            current, final = origin, dest
        else:
            current, final = dest, origin

        while current.n >= final.n:
            if current.n == final.n:
                break
            nodes.append(current)
            current = current.parent
        else:
            return None
        nodes.append(current)

        return reversed(nodes) if rev else nodes

    branch = _walk_branch(start, end)

    if not branch:
        vim.command('unsilent echo "No path to that node from here!"')
        return

    for node in branch:
        _undo_to(node.n)
        vim.command('GundoRenderGraph')
        normal('zz')
        vim.command('%dwincmd w' % int(vim.eval('back')))
        vim.command('redraw')
        vim.command('sleep 60m')

GundoPlayTo()
ENDPYTHON
endfunction"}}}

"}}}

"{{{ Misc
command! -nargs=0 GundoOpenGraph call s:GundoOpenGraph()
command! -nargs=0 GundoToggle call s:GundoToggle()
command! -nargs=0 GundoRenderGraph call s:GundoRenderGraph()
autocmd BufNewFile __Gundo__ call s:GundoSettingsGraph()
autocmd BufNewFile __Gundo_Preview__ call s:GundoSettingsPreview()
"}}}
