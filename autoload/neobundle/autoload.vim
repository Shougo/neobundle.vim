"=============================================================================
" FILE: autoload.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 17 Dec 2013.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

function! neobundle#autoload#init()
  augroup neobundle
    autocmd FileType *
          \ call neobundle#autoload#filetype()
    autocmd FuncUndefined *
          \ call neobundle#autoload#function()
    autocmd BufNewFile,BufRead *
          \ call neobundle#autoload#filename(expand('<afile>'))
    autocmd InsertEnter *
          \ call neobundle#autoload#insert()
    autocmd BufCreate
          \ * call neobundle#autoload#explorer(
          \ expand('<afile>'), 'BufCreate')
    autocmd BufEnter
          \ * call neobundle#autoload#explorer(
          \ expand('<afile>'), 'BufEnter')
    autocmd BufWinEnter
          \ * call neobundle#autoload#explorer(
          \ expand('<afile>'), 'BufWinEnter')
  augroup END

  call neobundle#autoload#filename(bufname('%'))
endfunction

function! neobundle#autoload#filetype()
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "has_key(v:val.autoload, 'filetypes')")
  for filetype in neobundle#util#get_filetypes()
    call neobundle#config#source_bundles(filter(copy(bundles),"
          \ index(neobundle#util#convert2list(
          \     v:val.autoload.filetypes), filetype) >= 0"))
  endfor
endfunction

function! neobundle#autoload#filename(filename)
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "has_key(v:val.autoload, 'filename_patterns')")
  if !empty(bundles)
    call neobundle#config#source_bundles(filter(copy(bundles),"
          \ len(filter(copy(neobundle#util#convert2list(
          \  v:val.autoload.filename_patterns)),
          \  'a:filename =~? v:val')) > 0"))
  endif
endfunction

function! neobundle#autoload#insert()
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "get(v:val.autoload, 'insert', 0)")
  if !empty(bundles)
    call neobundle#config#source_bundles(bundles)
    doautocmd InsertEnter
  endif
endfunction

function! neobundle#autoload#function()
  let function = expand('<amatch>')
  let function_prefix = get(split(function, '#'), 0, '') . '#'

  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "get(v:val.autoload, 'function_prefix', '').'#' ==# function_prefix ||
        \  (has_key(v:val.autoload, 'functions') &&
        \    index(neobundle#util#convert2list(
        \     v:val.autoload.functions), function) >= 0)")
  call neobundle#config#source_bundles(bundles)
endfunction

function! neobundle#autoload#command(command, name, args, bang, line1, line2)
  " Delete dummy commands.
  silent! execute 'delcommand' a:command

  call neobundle#config#source(a:name)

  let range = (a:line1 != a:line2) ? "'<,'>" : ''

  try
    execute range.a:command.a:bang a:args
  catch /^Vim\%((\a\+)\)\=:E481/
    " E481: No range allowed
    execute a:command.a:bang a:args
  endtry
endfunction

function! neobundle#autoload#mapping(mapping, name, mode)
  let cnt = v:count > 0 ? v:count : ''

  " Delete dummy mappings.
  let input = s:get_input()

  call neobundle#config#source(a:name)

  if a:mode ==# 'v' || a:mode ==# 'x'
    call feedkeys('gv', 'n')
  elseif a:mode ==# 'o'
    " TODO: omap
    " v:prevcount?
    " Cancel waiting operator mode.
    " call feedkeys("\<C-\\>\<C-n>", 'n')
    call feedkeys("\<Esc>", 'n')
    call feedkeys(v:operator, 'm')
  endif

  call feedkeys(cnt, 'n')

  let mapping = substitute(a:mapping, '<Plug>', "\<Plug>", 'g')
  call feedkeys(mapping . input, 'm')

  return ''
endfunction

function! neobundle#autoload#explorer(path, event)
  if bufnr('%') != expand('<abuf>') || a:path == ''
    return
  endif

  let path = a:path
  " For ":edit ~".
  if fnamemodify(path, ':t') ==# '~'
    let path = '~'
  endif

  let path = s:expand(path)
  if !(isdirectory(path) || (!filereadable(path) && path =~ '^\h\w\+://'))
    return
  endif

  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "get(v:val.autoload, 'explorer', 0)")
  if !empty(bundles)
    call neobundle#config#source_bundles(bundles)
    execute 'doautocmd' a:event
  endif
endfunction

function! neobundle#autoload#unite_sources(sources)
  let bundles = []
  let sources_bundles = filter(neobundle#config#get_autoload_bundles(),
          \ "has_key(v:val.autoload, 'unite_sources')")
  for source_name in a:sources
    if source_name ==# 'source'
      " In source source, load all sources.
      let bundles += copy(sources_bundles)
    else
      let bundles += filter(copy(sources_bundles),
            \ "index(neobundle#util#convert2list(
            \    v:val.autoload.unite_sources), source_name) >= 0")
    endif
  endfor

  call neobundle#config#source_bundles(neobundle#util#uniq(bundles))
endfunction

function! neobundle#autoload#get_unite_sources()
  let _ = []
  let sources_bundles = filter(neobundle#config#get_autoload_bundles(),
          \ "has_key(v:val.autoload, 'unite_sources')")
  for bundle in sources_bundles
    let _ += neobundle#util#convert2list(
          \ bundle.autoload.unite_sources)
  endfor

  return _
endfunction

function! neobundle#autoload#source(bundle_name)
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "index(neobundle#util#convert2list(
        \   get(v:val.autoload, 'on_source', [])), a:bundle_name) >= 0")
  call neobundle#config#source_bundles(bundles)
endfunction

function! s:get_input()
  let input = ''
  let termstr = "<M-_>"

  call feedkeys(termstr, 'n')

  while 1
    let input .= nr2char(getchar())

    let idx = stridx(input, termstr)
    if idx >= 1
      let input = input[: idx - 1]
      break
    elseif idx == 0
      let input = ''
      break
    endif
  endwhile

  return input
endfunction

function! s:expand(path)
  return neobundle#util#substitute_path_separator(
        \ (a:path =~ '^\~') ? substitute(a:path, '^\~', expand('~'), '') :
        \ (a:path =~ '^\$\h\w*') ? substitute(a:path,
        \               '^\$\h\w*', '\=eval(submatch(0))', '') :
        \ a:path)
endfunction

function! s:get_lazy_bundles()
  return filter(neobundle#config#get_neobundles(),
        \ "!neobundle#config#is_sourced(v:val.name)
        \ && v:val.rtp != '' && v:val.lazy")
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

