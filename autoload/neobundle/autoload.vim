"=============================================================================
" FILE: autoload.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
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
  let s:active_auto_source = 0

  augroup neobundle
    autocmd FileType *
          \ call neobundle#autoload#filetype()
    autocmd FuncUndefined *
          \ call neobundle#autoload#function()
    autocmd BufNewFile,BufRead *
          \ call neobundle#autoload#filename(expand('<afile>'))
    autocmd InsertEnter *
          \ call neobundle#autoload#insert()
  augroup END

  if has('patch-7.4.414')
    autocmd neobundle CmdUndefined *
          \ call neobundle#autoload#command_prefix()
  endif

  augroup neobundle-explorer
    autocmd!
  augroup END
  for event in ['BufRead', 'BufCreate', 'BufEnter', 'BufWinEnter', 'BufNew', 'VimEnter']
    execute 'autocmd neobundle-explorer' event "* call neobundle#autoload#explorer(
          \ expand('<afile>'), ".string(event) . ")"
  endfor

  augroup neobundle-focus
    autocmd!
    autocmd CursorHold * if s:active_auto_source
          \ | call s:source_focus()
          \ | endif
    autocmd FocusLost * let s:active_auto_source = 1
    autocmd FocusGained * let s:active_auto_source = 0
  augroup END

  call neobundle#autoload#filename(bufname('%'))
endfunction

function! neobundle#autoload#filetype()
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "has_key(v:val.autoload, 'filetypes')")
  for filetype in add(neobundle#util#get_filetypes(), 'all')
    call neobundle#config#source_bundles(filter(copy(bundles),"
          \ index(v:val.autoload.filetypes, filetype) >= 0"))
  endfor
endfunction

function! neobundle#autoload#filename(filename)
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "has_key(v:val.autoload, 'filename_patterns')")
  if !empty(bundles)
    call neobundle#config#source_bundles(filter(copy(bundles),"
          \ len(filter(copy(v:val.autoload.filename_patterns),
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
        \    index(v:val.autoload.functions, function) >= 0)")
  call neobundle#config#source_bundles(bundles)
endfunction

function! neobundle#autoload#command(command, name, args, bang, line1, line2)
  " Delete dummy commands.
  silent! execute 'delcommand' a:command

  call neobundle#config#source(a:name)

  let range = (a:line1 == a:line2) ? '' :
        \ (a:line1==line("'<") && a:line2==line("'>")) ?
        \ "'<,'>" : a:line1.",".a:line2

  try
    execute range.a:command.a:bang a:args
  catch /^Vim\%((\a\+)\)\=:E481/
    " E481: No range allowed
    execute a:command.a:bang a:args
  endtry
endfunction

function! neobundle#autoload#command_prefix()
  let command = expand('<afile>')

  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "get(v:val.autoload, 'command_prefix', '') != '' &&
        \  stridx(tolower(command),
        \  tolower(get(v:val.autoload, 'command_prefix', ''))) == 0")
  call neobundle#config#source_bundles(bundles)
endfunction

function! neobundle#autoload#mapping(mapping, name, mode)
  let cnt = v:count > 0 ? v:count : ''

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

  let mapping = a:mapping
  while mapping =~ '<[[:alnum:]-]\+>'
    let mapping = substitute(mapping, '\c<Leader>',
          \ get(g:, 'mapleader', '\'), 'g')
    let mapping = substitute(mapping, '\c<LocalLeader>',
          \ get(g:, 'maplocalleader', '\'), 'g')
    let ctrl = matchstr(mapping, '<\zs[[:alnum:]-]\+\ze>')
    execute 'let mapping = substitute(
          \ mapping, "<' . ctrl . '>", "\<' . ctrl . '>", "")'
  endwhile
  call feedkeys(mapping . input, 'm')

  return ''
endfunction

function! neobundle#autoload#explorer(path, event)
  if a:path == ''
    return
  endif

  let path = a:path
  " For ":edit ~".
  if fnamemodify(path, ':t') ==# '~'
    let path = '~'
  endif

  let path = neobundle#util#expand(path)
  if !(isdirectory(path) || (!filereadable(path) && path =~ '^\h\w\+://'))
    return
  endif

  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "get(v:val.autoload, 'explorer', 0)")
  if empty(bundles)
    augroup neobundle-explorer
      autocmd!
    augroup END
  else
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
            \ "!empty(filter(copy(v:val.autoload.unite_sources),
            \    'stridx(source_name, v:val) >= 0'))")
    endif
  endfor

  call neobundle#config#source_bundles(neobundle#util#uniq(bundles))
endfunction

function! neobundle#autoload#get_unite_sources()
  let _ = []
  let sources_bundles = filter(neobundle#config#get_autoload_bundles(),
          \ "has_key(v:val.autoload, 'unite_sources')")
  for bundle in sources_bundles
    let _ += bundle.autoload.unite_sources
  endfor

  return _
endfunction

function! s:source_focus()
  let bundles = neobundle#util#sort_by(filter(
        \ neobundle#config#get_autoload_bundles(),
        \ "v:val.focus > 0"), 'v:val.focus')
  if empty(bundles)
    augroup neobundle-focus
      autocmd!
    augroup END
    return
  endif

  call neobundle#config#source_bundles([bundles[0]])
  call feedkeys("g\<ESC>", 'n')
endfunction

function! neobundle#autoload#source(bundle_name)
  let bundles = filter(neobundle#config#get_neobundles(),
        \ "has_key(v:val.autoload, 'on_source') &&
        \   index(v:val.autoload.on_source, a:bundle_name) >= 0 &&
        \   !v:val.sourced && v:val.lazy")
  if !empty(bundles)
    call neobundle#config#source_bundles(bundles)
  endif
endfunction

function! s:get_input()
  let input = ''
  let termstr = "<M-_>"

  call feedkeys(termstr, 'n')

  let type_num = type(0)
  while 1
    let char = getchar()
    let input .= type(char) == type_num ? nr2char(char) : char

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

function! s:get_lazy_bundles()
  return filter(neobundle#config#get_neobundles(),
        \ "!neobundle#config#is_sourced(v:val.name)
        \ && v:val.rtp != '' && v:val.lazy")
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

