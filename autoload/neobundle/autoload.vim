"=============================================================================
" FILE: autoload.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 29 Dec 2012.
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
    call neobundle#config#source(filter(copy(bundles),"
          \ has_key(v:val.autoload.filetypes, filetype)"))
  endfor
endfunction

function! neobundle#autoload#function()
  let bundles = filter(s:get_autoload_bundles(),
        \ "has_key(v:val.autoload, 'functions') &&
        \  index(v:val.autoload.functions, expand('<afile>')) >= 0")
endfunction

function! neobundle#autoload#command(command, name, args)
  execute 'delcommand' a:command

  call neobundle#config#source(a:name)

  execute a:command a:args
endfunction

function! neobundle#autoload#mapping()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

