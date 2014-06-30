"=============================================================================
" FILE: git.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
"          Robert Nelson     <robert@rnelson.ca>
"          Copyright (C) 2010 http://github.com/gmarik
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

" Global options definition. "{{{
call neobundle#util#set_default(
      \ 'g:neobundle#types#git#command_path', 'git')
call neobundle#util#set_default(
      \ 'g:neobundle#types#git#default_protocol', 'https',
      \ 'g:neobundle_default_git_protocol')
call neobundle#util#set_default(
      \ 'g:neobundle#types#git#enable_submodule', 1)
call neobundle#util#set_default(
      \ 'g:neobundle#types#git#clone_depth', 0,
      \ 'g:neobundle_git_clone_depth')
"}}}

function! neobundle#types#git#define() "{{{
  return s:type
endfunction"}}}

let s:type = {
      \ 'name' : 'git',
      \ }

function! s:type.detect(path, opts) "{{{
  if isdirectory(a:path.'/.git')
    " Local repository.
    return { 'name' : split(a:path, '/')[-1],
          \  'uri' : a:path, 'type' : 'git' }
  elseif isdirectory(a:path)
    return {}
  endif

  let protocol = matchstr(a:path, '^.\{-}\ze://')
  if protocol == '' || a:path =~#
        \'\<\%(gh\|github\|bb\|bitbucket\):\S\+'
        \ || has_key(a:opts, 'type__protocol')
    let protocol = get(a:opts, 'type__protocol',
          \ g:neobundle#types#git#default_protocol)
  endif

  if a:path !~ '/'
    " www.vim.org Vim scripts.
    let name = split(a:path, ':')[-1]
    let uri  = (protocol ==# 'ssh') ?
          \ 'git@github.com:vim-scripts/' :
          \ protocol . '://github.com/vim-scripts/'
    let uri .= name
  else
    let name = substitute(split(a:path, ':')[-1],
          \   '^//github.com/', '', '')
    let uri =  (protocol ==# 'ssh') ?
          \ 'git@github.com:' . name :
          \ protocol . '://github.com/'. name
  endif

  if a:path !~# '\<\%(gh\|github\):\S\+\|://github.com/'
    let uri = s:parse_other_pattern(protocol, a:path, a:opts)
    if uri == ''
      " Parse failure.
      return {}
    endif
  endif

  if uri !~ '\.git\s*$'
    " Add .git suffix.
    let uri .= '.git'
  endif

  return { 'name': neobundle#util#name_conversion(uri),
        \  'uri': uri, 'type' : 'git' }
endfunction"}}}
function! s:type.get_sync_command(bundle) "{{{
  if !executable(g:neobundle#types#git#command_path)
    return 'E: "git" command is not installed.'
  endif

  if !isdirectory(a:bundle.path)
    let cmd = 'clone'
    if g:neobundle#types#git#enable_submodule
      let cmd .= ' --recursive'
    endif

    let depth = get(a:bundle, 'type__depth',
          \ g:neobundle#types#git#clone_depth)
    if depth > 0 && a:bundle.rev == '' && a:bundle.uri !~ '^git@'
      let cmd .= ' --depth=' . depth
    endif

    let cmd .= printf(' %s "%s"', a:bundle.uri, a:bundle.path)
  else
    let cmd = 'pull --rebase'
    if g:neobundle#types#git#enable_submodule
      let shell = fnamemodify(split(&shell)[0], ':t')
      let and = (!neobundle#util#has_vimproc() && shell ==# 'fish') ?
            \ '; and ' : ' && '

      let cmd .= and . g:neobundle#types#git#command_path
            \ . ' submodule update --init --recursive'
    endif
  endif

  return g:neobundle#types#git#command_path . ' ' . cmd
endfunction"}}}
function! s:type.get_revision_number_command(bundle) "{{{
  if !executable(g:neobundle#types#git#command_path)
    return ''
  endif

  let rev = a:bundle.rev
  if rev == ''
    let rev = 'HEAD'
  endif

  return g:neobundle#types#git#command_path .' rev-parse ' . rev
endfunction"}}}
function! s:type.get_revision_pretty_command(bundle) "{{{
  if !executable(g:neobundle#types#git#command_path)
    return ''
  endif

  return g:neobundle#types#git#command_path .
        \ ' log -1 --pretty=format:"%h [%cr] %s"'
endfunction"}}}
function! s:type.get_commit_date_command(bundle) "{{{
  if !executable(g:neobundle#types#git#command_path)
    return ''
  endif

  return g:neobundle#types#git#command_path .
        \ ' log -1 --pretty=format:"%ct"'
endfunction"}}}
function! s:type.get_log_command(bundle, new_rev, old_rev) "{{{
  if !executable(g:neobundle#types#git#command_path)
        \ || a:new_rev == '' || a:old_rev == ''
    return ''
  endif

  " Note: If the a:old_rev is not the ancestor of two branchs. Then do not use
  " %s^.  use %s^ will show one commit message which already shown last time.
  let is_not_ancestor = neobundle#util#system(
        \ g:neobundle#types#git#command_path . ' merge-base '
        \ . a:old_rev . ' ' . a:new_rev) ==# a:old_rev
  return printf(g:neobundle#types#git#command_path .
        \ ' log %s%s..%s --graph --pretty=format:"%%h [%%cr] %%s"',
        \ a:old_rev, (is_not_ancestor ? '' : '^'), a:new_rev)

  " Test.
  " return g:neobundle#types#git#command_path .
  "      \ ' log HEAD^^^^..HEAD --graph --pretty=format:"%h [%cr] %s"'
endfunction"}}}
function! s:type.get_revision_lock_command(bundle) "{{{
  if !executable(g:neobundle#types#git#command_path)
        \ || a:bundle.rev == ''
    return ''
  endif

  return g:neobundle#types#git#command_path . ' checkout ' . a:bundle.rev
endfunction"}}}
function! s:type.get_gc_command(bundle) "{{{
  if !executable(g:neobundle#types#git#command_path)
    return ''
  endif

  return g:neobundle#types#git#command_path .' gc'
endfunction"}}}
function! s:type.get_revision_remote_command(bundle) "{{{
  if !executable(g:neobundle#types#git#command_path)
    return ''
  endif

  let rev = a:bundle.rev
  if rev == ''
    let rev = 'HEAD'
  endif

  return g:neobundle#types#git#command_path
        \ .' ls-remote origin ' . rev
endfunction"}}}

function! s:parse_other_pattern(protocol, path, opts) "{{{
  let uri = ''

  if a:path =~# '\<gist:\S\+\|://gist.github.com/'
    let name = split(a:path, ':')[-1]
    let uri =  (a:protocol ==# 'ssh') ?
          \ 'git@gist.github.com:' . split(name, '/')[-1] :
          \ a:protocol . '://gist.github.com/'. split(name, '/')[-1]
  elseif a:path =~# '\<\%(git@\|git://\)\S\+'
        \ || a:path =~# '\.git\s*$'
        \ || get(a:opts, 'type', '') ==# 'git'
    if a:path =~# '\<\%(bb\|bitbucket\):\S\+'
      let name = substitute(split(a:path, ':')[-1],
            \   '^//bitbucket.org/', '', '')
      let uri = (a:protocol ==# 'ssh') ?
            \ 'git@bitbucket.org:' . name :
            \ a:protocol . '://bitbucket.org/' . name
    else
      let uri = a:path
    endif
  endif

  return uri
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
