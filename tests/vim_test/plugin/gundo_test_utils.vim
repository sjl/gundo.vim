let s:undolevels_save = &undolevels

function! g:Goto(buffername)"{{{
    exec bufwinnr(bufnr(a:buffername)) . 'wincmd w'
endfunction"}}}

function! g:GotoLineContaining(text)"{{{
    exe "silent! normal gg/\\M" . a:text . "\n"
endfunction"}}}

function! g:CurrentLineContains(text)"{{{
    if stridx(getline('.'), a:text) != -1
        return 1
    else
        return 0
    endif
endfunction"}}}

function! g:Contains(text)"{{{
    call g:GotoLineContaining(a:text)
    return g:CurrentLineContains(a:text)
endfunction"}}}

function! g:TypeLine(text)"{{{
    exe "normal i" . a:text . "\<C-g>u\n\e"
endfunction"}}}

function! g:TypeLineDone(text)"{{{
    exe "normal i" . a:text . "\n\e"

    " Break the undo chain
    let &undolevels = s:undolevels_save
endfunction"}}}

function! g:PrintTheFuckingBuffer()"{{{
    echo join(getline(1, 100000), "\n")
    echo "SOMETIMES I HATE YOU VIM"
endfunction"}}}

function! g:MoveUp()"{{{
    call cursor(line('.') - 1, 0)
endfunction"}}}

function! g:MoveDown()"{{{
    call cursor(line('.') + 1, 0)
endfunction"}}}
