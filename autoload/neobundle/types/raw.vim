"=============================================================================
" FILE: raw.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Oct 2012.
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

" Global options definition."{{{
call neobundle#util#set_default(
      \ 'g:neobundle#types#raw#calc_hash_command',
      \ executable('sha1sum') ? 'sha1sum' :
      \ executable('md5sum') ? 'md5sum' : '')
"}}}

function! neobundle#types#raw#define()"{{{
  return s:type
endfunction"}}}

let s:type = {
      \ 'name' : 'raw',
      \ }

function! s:type.detect(path, opts)"{{{
  " No auto detect.
  let type = ''

  if a:path =~# '^https\?:.*\.vim$'
    " HTTP/HTTPS

    let name = split(a:path, '/')[-1]

    let type = 'raw'
  endif

  return type == '' ?  {} :
        \ { 'name': name, 'uri' : a:path, 'type' : type }
endfunction"}}}
function! s:type.get_sync_command(bundle)"{{{
  if a:bundle.script_type == ''
    return 'E: script_type is not found.'
  endif

  if !executable('curl') && !executable('wget')
    return 'E: curl or wget command is not available!'
  endif

  let path = printf('%s/%s', a:bundle.path, a:bundle.script_type)

  if !isdirectory(path)
    " Create script type directory.
    call mkdir(path, 'p')
  endif

  let filename = path . '/' . fnamemodify(a:bundle.uri, ':t')
  if executable('curl')
    let cmd = 'curl --fail -s -o "' . filename . '" '. a:bundle.uri
  elseif executable('wget')
    let cmd = 'wget -q -O "' . filename . '" ' . a:bundle.uri
  endif

  return cmd
endfunction"}}}
function! s:type.get_revision_number_command(bundle)"{{{
  if g:neobundle#types#raw#calc_hash_command == ''
    return ''
  endif

  let path = printf('%s/%s', a:bundle.path, a:bundle.script_type)
  let filename = path . '/' . fnamemodify(a:bundle.uri, ':t')
  if !filereadable(path)
    " Not Installed.
    return ''
  endif

  " Calc hash.
  return g:neobundle#types#raw#calc_hash_command . ' ' . a:bundle.path
endfunction"}}}
function! s:type.get_revision_lock_command(bundle)"{{{
  " Not supported.
  return ''
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
