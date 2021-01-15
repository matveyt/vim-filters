" Vim plugin to run various text filters
" Maintainer:   matveyt
" Last Change:  2021 Jan 14
" License:      VIM License
" URL:          https://github.com/matveyt/vim-filters

let s:save_cpo = &cpo
set cpo&vim

function! filters#init_buffer() abort
    if &ul < 1
        throw 'filters: need a few undolevels'
    endif
    setlocal binary noswapfile
    let b:filters_changenr = changenr()
endfunction

function! filters#fini_buffer() abort
    unlet b:filters_changenr
    let [l:ul, &l:ul] = [&l:ul, -1]
    execute "normal! i\<Space>\<BS>"
    let &l:ul = l:ul
    setlocal nobinary swapfile<
endfunction

function! filters#do(name) abort
    let l:name = a:name
    let l:ext = fnamemodify(l:name, ':e')
    let l:list = []
    while g:FiltersPlugin.has_extension(l:ext)
        let l:changenr = changenr()
        for l:tool in g:FiltersPlugin.extension[l:ext]
            execute "normal! i\<C-G>u"
            if filters#run_tool(l:tool, l:ext, v:true)
                execute 'silent undo' l:changenr
                continue
            endif
            call insert(l:list, [l:tool, l:ext])
            if did_filetype()
                return l:list
            else
                break
            endif
        endfor
        let l:name = fnamemodify(l:name, ':r')
        let l:ext = fnamemodify(l:name, ':e')
    endwhile

    execute 'doautocmd filetypedetect BufReadPost' fnameescape(l:name)
    if !did_filetype()
        if empty(l:ext)
            setfiletype text
        elseif !filters#run_tool('xxd', l:ext, v:true)
            call insert(l:list, ['xxd', l:ext])
        endif
    endif

    return l:list
endfunction

function! filters#run_tool(tool, ext, dir) abort
    if !filters#executable(a:tool)
        return 127
    endif

    let l:tinfo = g:FiltersPlugin.tool[a:tool]
    let l:opts = a:dir ? l:tinfo.do : l:tinfo.undo
    if l:opts is v:null
        return 126
    endif
    let l:opts = substitute(l:opts, '\$1', a:ext, 'g')

    silent! execute "%!" fnameescape(l:tinfo.path) l:opts
    if v:shell_error
        if v:shell_error >= 126
            " disable tool
            let l:tinfo.checked = -1
        endif
        return v:shell_error
    endif

    if a:dir
        if empty(&buftype) && l:tinfo.undo is v:null
            setlocal buftype=nowrite
        endif
        if !empty(l:tinfo.ft)
            execute 'setfiletype' l:tinfo.ft
        endif
    endif
endfunction

function! filters#executable(tool) abort
    if !g:FiltersPlugin.has_tool(a:tool)
        return v:false
    endif
    let l:tinfo = g:FiltersPlugin.tool[a:tool]
    if !l:tinfo.checked
        if empty(l:tinfo.path)
            let l:tinfo.path = exepath(a:tool)
            let l:tinfo.checked = empty(l:tinfo.path) ? -1 : 1
            if has('nvim') && exists('+shellslash') && &shellslash
                "BUG: Neovim exepath() can return backslashes
                let tinfo.path = tr(tinfo.path, '\', '/')
            endif
        else
            let l:tinfo.checked = executable(l:tinfo.path) ? 1 : -1
        endif
    endif
    return l:tinfo.checked > 0 ? v:true : v:false
endfunction

" filters#hex({hex}, {extlist})
" hex or bless extension list
function! filters#hex(hex, extlist) abort
    if a:hex
        for l:ext in a:extlist
            let g:FiltersPlugin.extension[l:ext] = ['xxd']
        endfor
    else
        call filter(g:FiltersPlugin.extension,
            \ {k, v -> (index(a:extlist, k) < 0) || v != ['xxd']})
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
