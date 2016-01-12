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

function! neobundle#autoload#init() "{{{
  let s:active_auto_source = 0
  let s:loaded_path = 0

  augroup neobundle
    autocmd FileType *
          \ call s:on_filetype()
    autocmd FuncUndefined *
          \ call s:on_function()
    autocmd InsertEnter *
          \ call s:on_insert()
  augroup END

  if has('patch-7.4.414')
    autocmd neobundle CmdUndefined *
          \ call s:on_command_prefix()
  endif

  augroup neobundle-path
    autocmd!
  augroup END
  for event in [
        \ 'BufRead', 'BufCreate', 'BufEnter',
        \ 'BufWinEnter', 'BufNew', 'VimEnter'
        \ ]
    execute 'autocmd neobundle-path' event
          \ "* call s:on_path(expand('<afile>'), ".string(event) . ")"
  endfor

  augroup neobundle-focus
    autocmd!
    autocmd CursorHold * if s:active_auto_source
          \ | call s:source_focus()
          \ | endif
    autocmd FocusLost * let s:active_auto_source = 1 | call s:source_focus()
    autocmd FocusGained * let s:active_auto_source = 0
  augroup END
endfunction"}}}

function! neobundle#autoload#unite_sources(sources) "{{{
  let bundles = []
  let sources_bundles = filter(neobundle#config#get_autoload_bundles(),
          \ "!empty(v:val.on_unite)")
  for source_name in a:sources
    if source_name ==# 'source'
      " In source source, load all sources.
      let bundles += copy(sources_bundles)
    else
      let bundles += filter(copy(sources_bundles),
            \ "!empty(filter(copy(v:val.on_unite),
            \    'stridx(source_name, v:val) >= 0'))")
    endif
  endfor

  call neobundle#config#source_bundles(neobundle#util#uniq(bundles))
endfunction"}}}

function! neobundle#autoload#get_unite_sources() "{{{
  let _ = []
  let sources_bundles = filter(neobundle#config#get_autoload_bundles(),
          \ "!empty(v:val.on_unite)")
  for bundle in sources_bundles
    let _ += bundle.on_unite
  endfor

  return _
endfunction"}}}

function! neobundle#autoload#_command(command, name, args, bang, line1, line2) "{{{
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
endfunction"}}}

function! neobundle#autoload#_command_dummy_complete(arglead, cmdline, cursorpos) "{{{
  " Load plugins
  let command = tolower(matchstr(a:cmdline, '\a\S*'))

  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "!empty(filter(map(copy(v:val.pre_cmd), 'tolower(v:val)'),
        \   'stridx(command, v:val) == 0'))")
  call neobundle#config#source_bundles(bundles)

  " Print the candidates
  call feedkeys("\<C-d>", 'n')
  return ['']
endfunction"}}}

function! neobundle#autoload#_mapping(mapping, name, mode) "{{{
  let cnt = v:count > 0 ? v:count : ''

  let input = s:get_input()

  call neobundle#config#source(a:name)

  if a:mode ==# 'v' || a:mode ==# 'x'
    call feedkeys('gv', 'n')
  elseif a:mode ==# 'o'
    " TODO: omap
    " v:prevcount?
    " Cancel waiting operator mode.
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
endfunction"}}}

function! neobundle#autoload#_source(bundle_name) "{{{
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "index(v:val.on_source, a:bundle_name) >= 0")
  if !empty(bundles)
    call neobundle#config#source_bundles(bundles)
  endif
endfunction"}}}

function! neobundle#autoload#_set_function_prefixes(bundles) abort "{{{
  for bundle in filter(copy(a:bundles), "empty(v:val.pre_func)")
    let bundle.pre_func =
          \ neobundle#util#uniq(map(split(globpath(
          \  bundle.path, 'autoload/**/*.vim', 1), "\n"),
          \  "substitute(matchstr(
          \   neobundle#util#substitute_path_separator(
          \         fnamemodify(v:val, ':r')),
          \         '/autoload/\\zs.*$'), '/', '#', 'g').'#'"))
  endfor
endfunction"}}}

function! s:on_filetype() "{{{
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "!empty(v:val.on_ft)")
  for filetype in add(neobundle#util#get_filetypes(), 'all')
    call neobundle#config#source_bundles(filter(copy(bundles),"
          \ index(v:val.on_ft, filetype) >= 0"))
  endfor
endfunction"}}}

function! s:on_insert() "{{{
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "v:val.on_i")
  if !empty(bundles)
    call neobundle#config#source_bundles(bundles)
    doautocmd InsertEnter
  endif
endfunction"}}}

function! s:on_function() "{{{
  let function = expand('<amatch>')
  let function_prefix = substitute(function, '[^#]*$', '', '')
  if function_prefix =~# '^neobundle#'
        \ || function_prefix ==# 'vital#'
        \ || has('vim_starting')
    return
  endif

  let bundles = neobundle#config#get_autoload_bundles()
  call neobundle#autoload#_set_function_prefixes(bundles)

  let bundles = filter(bundles,
        \ "index(v:val.pre_func, function_prefix) >= 0
        \ || (index(v:val.on_func, function) >= 0)")
  call neobundle#config#source_bundles(bundles)
endfunction"}}}

function! s:on_command_prefix() "{{{
  let command = tolower(expand('<afile>'))

  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "!empty(filter(map(copy(v:val.pre_cmd), 'tolower(v:val)'),
        \   'stridx(command, v:val) == 0'))")
  call neobundle#config#source_bundles(bundles)
endfunction"}}}

function! s:on_path(path, event) "{{{
  if a:path == ''
    return
  endif

  let path = a:path
  " For ":edit ~".
  if fnamemodify(path, ':t') ==# '~'
    let path = '~'
  endif

  let path = neobundle#util#expand(path)
  let bundles = filter(neobundle#config#get_autoload_bundles(),
        \ "len(filter(copy(v:val.on_path),
          \  'path =~? v:val')) > 0")")
  if empty(bundles)
    augroup neobundle-path
      autocmd!
    augroup END
  else
    call neobundle#config#source_bundles(bundles)
    execute 'doautocmd' a:event

    if !s:loaded_path && has('vim_starting')
          \ && neobundle#util#redir('filetype') =~# 'detection:ON'
      " Force enable auto detection if path bundles are loaded
      autocmd neobundle VimEnter * filetype detect
    endif
    let s:loaded_path = 1
  endif
endfunction"}}}

function! s:source_focus() "{{{
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
endfunction"}}}

function! s:get_input() "{{{
  let input = ''
  let termstr = "<M-_>"

  call feedkeys(termstr, 'n')

  let type_num = type(0)
  while 1
    let char = getchar()
    let input .= (type(char) == type_num) ? nr2char(char) : char

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
endfunction"}}}

function! s:get_lazy_bundles() "{{{
  return filter(neobundle#config#get_neobundles(),
        \ "!v:val.sourced && v:val.rtp != '' && v:val.lazy")
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

