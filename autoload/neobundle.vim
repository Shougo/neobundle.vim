"=============================================================================
" FILE: neobundle.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 21 Apr 2012.
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
" Version: 1.0, for Vim 7.2
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

let g:neobundle_default_git_protocol =
      \ get(g:, 'neobundle_default_git_protocol', 'git')

command! -nargs=+ NeoBundle call neobundle#config#bundle(
      \ substitute(<q-args>, '\s"[^\-:.%#=*].*$', '', ''))

command! -nargs=+ NeoExternalBundle
      \ call neobundle#config#external_bundle(<args>)

command! -nargs=? -bang
      \ -complete=customlist,neobundle#complete_bundles
      \ NeoBundleInstall
      \ call neobundle#installer#install('!' == '<bang>', <q-args>)
command! -nargs=?
      \ -complete=customlist,neobundle#complete_bundles
      \ NeoBundleUpdate
      \ call neobundle#installer#install(1, <q-args>)

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
        \ neobundle#util#substitute_path_separator(
        \ neobundle#util#expand(get(a:000, 0, '~/.vim/bundle')))
  call neobundle#config#init()
endfunction

function! neobundle#get_neobundle_dir()
  return s:neobundle_dir
endfunction

function! neobundle#complete_bundles(arglead, cmdline, cursorpos)
  return filter(map(neobundle#config#get_neobundles(), 'v:val.name'),
          \ 'stridx(v:val, a:arglead) == 0')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

