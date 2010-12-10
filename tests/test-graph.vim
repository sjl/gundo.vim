UTSuite [Gundo] Testing Toggling

function! s:Setup()"{{{
    exec 'edit test'
    call g:Goto('test')
    setlocal buftype=nofile
endfunction"}}}
function! s:Teardown()"{{{
    if bufwinnr(bufnr('__Gundo__')) != -1
        exec bufwinnr(bufnr('__Gundo__')) . 'wincmd w'
        quit
    endif
    if bufwinnr(bufnr('__Gundo_Preview__')) != -1
        exec bufwinnr(bufnr('__Gundo_Preview__')) . 'wincmd w'
        quit
    endif
    if bufnr('__Gundo__') != -1
        exec 'bwipeout ' . bufnr('__Gundo__')
    endif
    if bufnr('__Gundo_Preview__') != -1
        exec 'bwipeout ' . bufnr('__Gundo_Preview__')
    endif
    if bufnr('test') != -1
        exec 'bwipeout ' . bufnr('test')
    endif
    if bufnr('test2') != -1
        exec 'bwipeout ' . bufnr('test2')
    endif
endfunction"}}}

function! s:TestToggleBasic()"{{{
    call g:TypeLine("ONE")
    call g:TypeLineDone("TWO")

    GundoToggle

    Assert g:Contains("o  [0]")
    Assert g:Contains("o  [1]")
    Assert g:Contains("@  [2]")
    Assert !g:Contains("[3]")
endfunction"}}}

function! s:TestToggleBranches()"{{{
    call g:TypeLineDone("ONE")
    silent! undo
    call g:TypeLineDone("TWO")

    GundoToggle

    " Make sure there is a branch next to state 2
    call g:GotoLineContaining("[1]")
    Assert g:CurrentLineContains("|")

    " Make sure there is no branch next to states 0 and 2
    call g:GotoLineContaining("[0]")
    Assert !g:CurrentLineContains("|")
    call g:GotoLineContaining("[2]")
    Assert !g:CurrentLineContains("|")

    " Make sure the branch point is directly above state 0
    call g:GotoLineContaining("[0]")
    call g:MoveUp()
    Assert g:CurrentLineContains("|/")
endfunction"}}}
