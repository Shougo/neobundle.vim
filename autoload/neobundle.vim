"=============================================================================
" FILE: neobundle.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 21 Dec 2011.
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
" Version: 0.1, for Vim 7.2
"=============================================================================

command! -nargs=+ NeoBundle
      \ call neobundle#config#bundle(<args>)

command! -nargs=+ NeoExternalBundle
      \ call neobundle#config#external_bundle(<args>)

command! -nargs=? -bang NeoBundleInstall
      \ call neobundle#installer#install('!' == '<bang>', <q-args>)

command! -nargs=? -bang NeoBundleClean
      \ call neobundle#installer#clean('!' == '<bang>', <q-args>)

command! -nargs=? -bang NeoBundleList
      \ echo join(map(neobundle#config#get_neobundles(), 'v:val.name'), "\n")

command! -nargs=0 NeoBundleDocs
      \ call neobundle#installer#helptags(neobundle#config#get_neobundles())

command! -nargs=0 NeoBundleLog echo join(neobundle#installer#get_log(), "\n")

augroup neobundle
  autocmd!
  autocmd Syntax  vim syntax keyword vimCommand NeoBundle
augroup END

function! neobundle#rc(...)
  let s:neobundle_dir =
        \ substitute(expand(get(a:000, 0, '~/.vim/bundle')), '\\', '/', 'g')
  call neobundle#config#init()
endfunction

function! neobundle#get_neobundle_dir()
  return s:neobundle_dir
endfunction

