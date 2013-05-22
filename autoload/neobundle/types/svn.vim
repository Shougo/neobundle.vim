"=============================================================================
" FILE: svn.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 22 May 2013.
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

function! neobundle#types#svn#define() "{{{
  return s:type
endfunction"}}}

let s:type = {
      \ 'name' : 'svn',
      \ }

function! s:type.detect(path, opts) "{{{
  let type = ''

  if a:path =~# '\<\%(file\|https\?\|svn\)://'
        \ && a:path =~? '[/.]svn[/.]'
    let uri = a:path
    let name = split(uri, '/')[-1]

    let type = 'svn'
  elseif a:path =~# '\<\%(gh\|github\):\S\+\|://github.com/'
    let name = substitute(split(a:path, ':')[-1],
          \   '^//github.com/', '', '')
    let uri =  'https://github.com/'. name
    let uri .= '/trunk'

    let name = split(name, '/')[-1]

    let type = 'svn'
  endif

  return type == '' ?  {} :
        \ { 'name': name, 'uri': uri, 'type' : type }
endfunction"}}}
function! s:type.get_sync_command(bundle) "{{{
  if !executable('svn')
    return 'E: svn command is not installed.'
  endif

  if !isdirectory(a:bundle.path)
    let cmd = 'svn checkout'
    let cmd .= printf(' %s "%s"', a:bundle.uri, a:bundle.path)
  else
    let cmd = 'svn up'
  endif

  return cmd
endfunction"}}}
function! s:type.get_revision_number_command(bundle) "{{{
  if !executable('svn')
    return ''
  endif

  return 'svn info'
endfunction"}}}
function! s:type.get_revision_lock_command(bundle) "{{{
  if !executable('svn') || a:bundle.rev == ''
    return ''
  endif

  return 'svn up -r ' . a:bundle.rev
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
