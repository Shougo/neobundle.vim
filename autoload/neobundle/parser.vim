"=============================================================================
" FILE: parser.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 18 Jun 2013.
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

function! neobundle#parser#bundle(arg, ...) "{{{
  let bundle = s:parse_arg(a:arg)
  let is_parse_only = get(a:000, 0, 0)
  if empty(bundle) || is_parse_only
    return bundle
  endif

  call neobundle#config#add(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#lazy(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  " Update lazy flag.
  let bundle.lazy = 1
  let bundle.resettable = 0
  for depend in bundle.depends
    let depend.lazy = bundle.lazy
    let depend.resettable = 0
  endfor

  call neobundle#config#add(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#fetch(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  " Clear runtimepath.
  let bundle.rtp = ''

  call neobundle#config#add(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#depends(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  if !has_key(s:neobundles, bundle.name)
    let bundle.overwrite = 0
    let bundle.resettable = 0

    call neobundle#config#add(bundle)

    " Install bundle automatically.
    silent call neobundle#installer#install(0, bundle.name)
  endif

  " Load scripts.
  call neobundle#config#source(bundle.name)

  return bundle
endfunction"}}}

function! neobundle#parser#direct(arg) "{{{
  let bundle = neobundle#parser#bundle(a:arg)

  if empty(bundle)
    return {}
  endif

  let path = bundle.path

  let s:direct_neobundles[path] = bundle
  call neobundle#config#save_direct_bundles()

  " Direct install.
  call neobundle#installer#install(0, bundle.name)

  return bundle
endfunction"}}}

function! s:parse_arg(arg) "{{{
  let arg = type(a:arg) == type([]) ?
   \ string(a:arg) : '[' . a:arg . ']'
  sandbox let args = eval(arg)
  if empty(args)
    return {}
  endif

  let bundle = neobundle#config#init_bundle(
        \ args[0], args[1:])
  if empty(bundle)
    return {}
  endif

  let bundle.orig_arg = a:arg

  if !empty(bundle.external_commands)
    call neobundle#config#check_external_commands(bundle)
  endif

  return bundle
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
