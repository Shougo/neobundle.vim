"=============================================================================
" FILE: autoload.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 04 Jan 2013.
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

function! s:get_autoload_bundles()
  return filter(neobundle#config#get_neobundles(),
        \ "!neobundle#config#is_sourced(v:val.name) && v:val.rtp != ''
        \   && has_key(v:val, 'autoload')")
endfunction

function! neobundle#autoload#filetype()
  let bundles = filter(s:get_autoload_bundles(),
        \ "has_key(v:val.autoload, 'filetypes')")
  for filetype in neobundle#util#get_filetypes()
    call neobundle#config#source_bundles(filter(copy(bundles),"
          \ index(neobundle#util#convert_list(
          \     v:val.autoload.filetypes), filetype) >= 0"))
  endfor
endfunction

function! neobundle#autoload#insert()
  let bundles = filter(s:get_autoload_bundles(),
        \ "get(v:val.autoload, 'insert', 0)")
  if !empty(bundles)
    call neobundle#config#source_bundles(bundles)
    doautocmd InsertEnter
  endif
endfunction

function! neobundle#autoload#function()
  let bundles = filter(s:get_autoload_bundles(),
        \ "has_key(v:val.autoload, 'functions') &&
        \  index(neobundle#util#convert_list(
        \     v:val.autoload.functions), expand('<afile>')) >= 0")
  call neobundle#config#source_bundles(bundles)
endfunction

function! neobundle#autoload#command(command, name, args, bang)
  execute 'delcommand' a:command

  call neobundle#config#source(a:name)

  execute a:command.a:bang a:args
endfunction

function! neobundle#autoload#mapping(mapping, name, mode)
  let input = s:get_input()

  execute a:mode.'unmap' a:mapping

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

  let mapping = substitute(a:mapping, '<Plug>', "\<Plug>", 'g')
  call feedkeys(mapping . input, 'm')
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

let &cpo = s:save_cpo
unlet s:save_cpo

