" Vim plugin to run various text filters
" Maintainer:   matveyt
" Last Change:  2021 Jan 14
" License:      VIM License
" URL:          https://github.com/matveyt/vim-filters

if exists('g:loaded_filters') || !exists('g:did_load_filetypes')
    finish
endif
let g:loaded_filters = 1

let s:save_cpo = &cpo
set cpo&vim

let g:FiltersPlugin = {'tool': {}, 'extension': {}}
const s:default_tool = {
    \ 'path': v:null,
    \ 'do': '-d',
    \ 'undo': '',
    \ 'ft': v:null,
    \ 'checked': 0
\ }

function! FiltersPlugin.acceptable(name) abort
    return has_key(self.extension, fnamemodify(a:name, ':e'))
endfunction

function! FiltersPlugin.has_tool(tool) abort
    return has_key(self.tool, a:tool)
endfunction

function! FiltersPlugin.has_extension(ext) abort
    return has_key(self.extension, a:ext)
endfunction

function! FiltersPlugin.set_tool(tool, ...) abort
    let self.tool[a:tool] = extend(copy(s:default_tool), get(a:, 1, {}))
endfunction

function! FiltersPlugin.set_extension(ext, tool) abort
    if type(a:tool) == v:t_list
        let self.extension[a:ext] = a:tool[:]
    else
        let self.extension[a:ext] = [a:tool]
    endif
endfunction

function! FiltersPlugin.default_tools() abort
    call self.set_tool('xxd', {'do': '-g1 -u', 'undo': '-r', 'ft': 'xxd'})
    call self.set_tool('catdoc', {'do': '', 'undo': v:null, 'ft': 'text'})
    call self.set_tool('djvutxt', {'do': '-', 'undo': v:null, 'ft': 'text'})
    call self.set_tool('pandoc', {'do': '-f$1 -tplain --eol=lf', 'undo': v:null,
        \ 'ft': 'text'})
    call self.set_tool('pdftotext', {'do': '-layout - -', 'undo': v:null, 'ft': 'text'})
    call self.set_tool('brotli')
    call self.set_tool('bzip2')
    call self.set_tool('compress')
    call self.set_tool('gzip')
    call self.set_tool('lzip')
    call self.set_tool('lzma')
    call self.set_tool('lzop')
    call self.set_tool('xz')
    call self.set_tool('zstd')
endfunction

function! FiltersPlugin.default_extensions() abort
    call self.set_extension('br', 'brotli')
    call self.set_extension('bz2', 'bzip2')
    call self.set_extension('djv', 'djvutxt')
    call self.set_extension('djvu', 'djvutxt')
    call self.set_extension('doc', 'catdoc')
    call self.set_extension('docx', 'pandoc')
    call self.set_extension('epub', 'pandoc')
    call self.set_extension('fb2', 'pandoc')
    call self.set_extension('gz', 'gzip')
    call self.set_extension('lz', 'lzip')
    call self.set_extension('lzma', 'lzma')
    call self.set_extension('lzo', 'lzop')
    call self.set_extension('odt', 'pandoc')
    call self.set_extension('pdf', 'pdftotext')
    call self.set_extension('rtf', 'catdoc')
    call self.set_extension('xz', 'xz')
    call self.set_extension('zst', 'zstd')
    call self.set_extension('Z', ['compress', 'gzip'])
endfunction

function! FiltersPlugin.ft_ignore_pat(...) abort
    let l:ignore = split(matchstr(a:0 ? a:1 : g:ft_ignore_pat,
        \ '\\\.\\(\zs.*\ze\\)\$'), '\\|')
    call uniq(sort(extend(l:ignore, keys(self.extension))))
    return '\.\('..join(l:ignore, '\|')..'\)$'
endfunction

function s:pre_read(name) abort
    if g:FiltersPlugin.acceptable(a:name)
        call filters#init_buffer()
    endif
endfunction

function s:post_read(name) abort
    if exists('b:filters_changenr')
        let b:filters_list = filters#do(a:name)
        call filters#fini_buffer()
    endif
endfunction

function s:pre_write(name) abort
    if exists('b:filters_list') && g:FiltersPlugin.acceptable(a:name)
        call filters#init_buffer()
        execute "normal! i\<C-G>u"
        for l:item in b:filters_list
            if filters#run_tool(l:item[0], l:item[1], v:false)
                execute 'silent! undo' b:filters_changenr
                call filters#fini_buffer()
                throw 'filters: failed to prepare for writing'
            endif
        endfor
    endif
endfunction

function s:post_write(name) abort
    if exists('b:filters_changenr')
        execute 'silent! undo' b:filters_changenr
        call filters#fini_buffer()
    endif
endfunction

augroup FiltersPlugin | au!
    autocmd BufReadPre * call s:pre_read(expand('<afile>'))
    autocmd BufReadPost * call s:post_read(expand('<afile>'))
    autocmd BufWritePre * call s:pre_write(expand('<afile>'))
    autocmd BufWritePost * call s:post_write(expand('<afile>'))
augroup end

if !get(g:, 'filters_no_defaults')
    call g:FiltersPlugin.default_tools()
    call g:FiltersPlugin.default_extensions()
    let g:ft_ignore_pat = g:FiltersPlugin.ft_ignore_pat()
endif
command! -bar -bang -nargs=+ Hex call filters#hex(<bang>1, [<f-args>])

let &cpo = s:save_cpo
unlet s:save_cpo
