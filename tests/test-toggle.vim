UTSuite [Gundo] Testing Toggling

function! s:Setup()"{{{
    exec 'edit test'
    call g:Goto('test')
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
    " Make sure we're starting from scratch.
    Assert bufnr('__Gundo__') == -1
    Assert bufnr('__Gundo_Preview__') == -1
    Assert bufwinnr(bufnr('__Gundo__')) == -1
    Assert bufwinnr(bufnr('__Gundo_Preview__')) == -1

    " Open Gundo
    GundoToggle

    " Buffers and windows should exist.
    Assert bufnr('__Gundo__') != -1
    Assert bufnr('__Gundo_Preview__') != -1
    Assert bufwinnr(bufnr('__Gundo__')) != -1
    Assert bufwinnr(bufnr('__Gundo_Preview__')) != -1

    " We should be in the Gundo pane.
    Assert expand('%') == '__Gundo__'

    " Close Gundo
    GundoToggle

    " Windows should have been closed, but buffers should remain.
    Assert bufnr('__Gundo__') != -1
    Assert bufnr('__Gundo_Preview__') != -1
    Assert bufwinnr(bufnr('__Gundo__')) == -1
    Assert bufwinnr(bufnr('__Gundo_Preview__')) == -1
endfunction"}}}

function! s:TestToggleWhenMoved()"{{{
    " Make sure we're starting from scratch.
    Assert bufnr('__Gundo__') == -1
    Assert bufnr('__Gundo_Preview__') == -1
    Assert bufwinnr(bufnr('__Gundo__')) == -1
    Assert bufwinnr(bufnr('__Gundo_Preview__')) == -1

    " Open Gundo
    GundoToggle

    call g:Goto('test')
    Assert expand('%') == 'test'

    " Close Gundo
    GundoToggle

    " Windows should have been closed, but buffers should remain.
    Assert bufnr('__Gundo__') != -1
    Assert bufnr('__Gundo_Preview__') != -1
    Assert bufwinnr(bufnr('__Gundo__')) == -1
    Assert bufwinnr(bufnr('__Gundo_Preview__')) == -1

    " Open Gundo
    GundoToggle

    call g:Goto('__Gundo_Preview__')
    Assert expand('%') == '__Gundo_Preview__'

    " Close Gundo
    GundoToggle

    " Windows should have been closed, but buffers should remain.
    Assert bufnr('__Gundo__') != -1
    Assert bufnr('__Gundo_Preview__') != -1
    Assert bufwinnr(bufnr('__Gundo__')) == -1
    Assert bufwinnr(bufnr('__Gundo_Preview__')) == -1
endfunction"}}}

function! s:TestToggleReturnToTarget()"{{{
    " Make sure we're starting from scratch.
    Assert bufnr('__Gundo__') == -1
    Assert bufnr('__Gundo_Preview__') == -1
    Assert bufwinnr(bufnr('__Gundo__')) == -1
    Assert bufwinnr(bufnr('__Gundo_Preview__')) == -1

    exec 'new test2'
    call g:Goto('test')

    " Toggle Gundo
    GundoToggle
    GundoToggle

    " We should be returned to test
    Assert expand('%') == 'test'

    " Move to test2
    call g:Goto('test2')

    " Toggle Gundo
    GundoToggle
    GundoToggle

    " We should be returned to test2
    Assert expand('%') == 'test2'
endfunction"}}}
