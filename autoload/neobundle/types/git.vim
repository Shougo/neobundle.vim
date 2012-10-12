"=============================================================================
" FILE: git.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 08 Oct 2012.
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
      \ 'g:neobundle#types#git#default_protocol', 'git',
      \ 'g:neobundle_default_git_protocol')
"}}}

function! neobundle#types#git#define()"{{{
  return s:type
endfunction"}}}

let s:type = {
      \ 'name' : 'git',
      \ }

function! s:type.detect(path)"{{{
  let type = ''

  if a:path =~# '\<\(gh\|github\):\S\+\|://github.com/'
    if a:path !~ '/'
      " www.vim.org Vim scripts.
      let name = split(a:path, ':')[-1]
      let uri  = g:neobundle#types#git#default_protocol .
            \ '://github.com/vim-scripts/'.name.'.git'
      let type = 'git'
    else
      let uri = (a:path =~# '://github.com/') ? a:path :
            \ g:neobundle#types#git#default_protocol .
            \   '://github.com/'.substitute(split(a:path, ':')[-1],
            \   '^//github.com/', '', '')
      if uri !~ '\.git\s*$'
        " Add .git suffix.
        let uri .= '.git'
      endif

      let name = substitute(split(uri, '/')[-1], '\.git\s*$','','i')
    endif

    let type = 'git'
  elseif a:path =~# '\<\%(git@\|git://\)\S\+'
        \ || a:path =~# '\.git\s*$'
    if a:path =~# '\<\(bb\|bitbucket\):\S\+'
      let uri = g:neobundle#types#git#default_protocol .
            \ '://bitbucket.org/'.split(a:path, ':')[-1]
    else
      let uri = a:path
    endif
    let name = split(substitute(uri, '/\?\.git\s*$','','i'), '/')[-1]

    let type = 'git'
  endif

  return type == '' ?  {} :
        \ { 'name': name, 'uri': uri, 'type' : type }
endfunction"}}}
function! s:type.get_sync_command(bundle)"{{{
  if !executable('git')
    return 'E: "git" command is not installed.'
  endif

  if !isdirectory(a:bundle.path)
    let cmd = 'git clone'
    if get(a:bundle, 'type__shallow', 1)
          \ || a:bundle.uri !~ '^git@github.com:'
      " Use shallow clone.
      let cmd .= ' --depth 1'
    endif
    let cmd .= printf(' %s "%s"', a:bundle.uri, a:bundle.path)
  else
    let cmd = 'git pull --rebase'

    if get(a:bundle, 'rev', '') != ''
      " Restore revision.
      let cmd = 'git checkout master && ' . cmd
    endif
  endif
  return cmd
endfunction"}}}
function! s:type.get_revision_number_command(bundle)"{{{
  if !executable('git')
    return ''
  endif

  let rev = get(a:bundle, 'rev', '')
  if rev == ''
    let rev = 'HEAD'
  endif

  return 'git rev-parse ' . rev
endfunction"}}}
function! s:type.get_revision_pretty_command(bundle)"{{{
  if !executable('git')
    return ''
  endif

  return "git log -1 --pretty=format:'%h [%cr] %s'"
endfunction"}}}
function! s:type.get_log_command(bundle, new_rev, old_rev)"{{{
  if !executable('git') || a:new_rev == '' || a:old_rev == ''
    return ''
  endif

  " if the a:old_rev is not the ancestor of two branchs. then do not use %s^.
  " use %s^ will show one commit message which already shown last time.
  " Shougo, you can improve this.
  if system("git merge-base " . a:old_rev . a:new_rev) ==# a:old_rev
    return printf("git log %s..%s --graph --pretty=format:'%%h [%%cr] %%s'",
          \ a:old_rev, a:new_rev)
  else
    return printf("git log %s^..%s --graph --pretty=format:'%%h [%%cr] %%s'",
          \ a:old_rev, a:new_rev)
    " return "git log HEAD^^^^..HEAD --graph --pretty=format:'%h [%cr] %s'"
  endif
endfunction"}}}
function! s:type.get_revision_lock_command(bundle)"{{{
  if !executable('git')
    return ''
  endif

  return 'git checkout ' . a:bundle.rev
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
