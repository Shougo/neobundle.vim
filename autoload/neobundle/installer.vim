"=============================================================================
" FILE: installer.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 19 Oct 2011.
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

" Create vital module for neobundle
let s:V = vital#of('neobundle')

" Wrapper function of system()
function! s:system(...)
  return call(s:V.system,a:000,s:V)
endfunction

function! s:get_last_status(...)
  return call(s:V.get_last_status,a:000,s:V)
endfunction

function! neobundle#installer#install(bang, ...)
  let bundle_dir = neobundle#get_neobundle_dir()
  if !isdirectory(bundle_dir)
    call mkdir(bundle_dir, 'p')
  endif

  let bundles = (a:1 == '') ?
        \ neobundle#config#get_neobundles() :
        \ map(copy(a:000), 'neobundle#config#init_bundle(v:val, {})')

  let installed = s:install(a:bang, bundles)
  redraw!

  call s:log("Installed bundles:\n".join((empty(installed) ?
  \      ['no new bundles installed'] :
  \      map(installed, 'v:val.name')),"\n"))

  call neobundle#installer#helptags(bundles)
endf

function! neobundle#installer#helptags(bundles)
  if empty(a:bundles)
    return
  endif

  let help_dirs = filter(a:bundles, 'v:val.has_doc()')
  call map(help_dirs, 'v:val.helptags()')
  if !empty(help_dirs)
    call s:log('Helptags: done. '.len(help_dirs).' bundles processed')
  endif
  return help_dirs
endfunction

function! neobundle#installer#clean(bang, ...)
  let bundle_dirs = map(copy(neobundle#config#get_neobundles()), 'v:val.path')
  let all_dirs = split(globpath(neobundle#get_neobundle_dir(), '*'), "\n")
  let x_dirs = filter(all_dirs, 'index(bundle_dirs, v:val) < 0')

  let rm_dirs = a:0 ==  0 ? [] :
        \ map(neobundle#config#search(a:000), 'v:val.path')
  let x_dirs += rm_dirs

  if empty(x_dirs)
    call s:log("All clean!")
    return
  end

  if a:bang || s:check_really_clean(x_dirs)
    let cmd = (has('win32') || has('win64')) && !executable('rm') ?
          \ 'rmdir /S /Q' : 'rm -rf'
    redraw
    let result = s:system(cmd . ' ' . join(map(x_dirs, '"\"" . v:val . "\""'), ' '))
    if s:get_last_status()
      call s:error(result)
    endif

    for dir in rm_dirs
      call neobundle#config#rm_bndle(dir)
    endfor
  endif
endfunction

function! neobundle#installer#get_sync_command(bang, bundle, number, max)
  let repo_dir = expand(a:bundle.path.'/.'.a:bundle.type.'/')
  if isdirectory(repo_dir)
    if !a:bang
      return ['', printf('(%d/%d): %s', a:number, a:max, 'Skipped')]
    endif

    if a:bundle.type == 'svn'
      let cmd = 'svn up'
    elseif a:bundle.type == 'hg'
      let cmd = 'hg pull && hg up'
    elseif a:bundle.type == 'git'
      let cmd = 'git pull'
    else
      return ['', printf('(%d/%d): %s', a:number, a:max, 'Unknown')]
    endif

    "cd to bundle path"
    let path = a:bundle.path
    lcd `=path`

    let message = printf('(%d/%d): %s', a:number, a:max, path)
    redraw
  else
    if a:bundle.type == 'svn'
      let cmd = 'svn checkout'
    elseif a:bundle.type == 'hg'
      let cmd = 'hg clone'
    elseif a:bundle.type == 'git'
      let cmd = 'git clone'
    else
      return ['', printf('(%d/%d): %s', a:number, a:max, 'Unknown')]
    endif
    let cmd .= ' ' . a:bundle.uri . ' "'. a:bundle.path .'"'

    let message = printf('(%d/%d): %s', a:number, a:max, cmd)
    redraw
  endif

  let rev = get(a:bundle, 'rev', '')
  if rev != ''
    let cmd .= '&&'

    " Lock revision.
    if a:bundle.type == 'svn'
      let cmd .= 'svn up'
    elseif a:bundle.type == 'hg'
      let cmd .= 'hg pull && hg up'
    elseif a:bundle.type == 'git'
      let cmd .= 'git pull'
    else
      return ['', printf('(%d/%d): %s', a:number, a:max, 'Unknown')]
    endif

    let cmd .= ' ' . rev
  endif

  return [cmd, message]
endfunction

function! s:sync(bang, bundle, number, max)
  if a:bundle.type == 'nosync' | return 'todate' | endif

  let cwd = getcwd()

  let [cmd, message] = neobundle#installer#get_sync_command(
        \ a:bang, a:bundle, a:number, a:max)
  call s:log(message)
  if cmd == ''
    " Skipped.
    return 0
  endif

  let result = s:system(cmd)
  echo ''
  redraw

  if getcwd() !=# cwd
    lcd `=cwd`
  endif

  if result =~# 'up-to-date'
    return 0
  endif

  if s:get_last_status()
    call s:error(a:bundle.path)
    call s:error(result)
    return 0
  endif

  return 1
endfunction

function! s:install(bang, bundles)
  let i = 1
  let _ = []
  let max = len(a:bundles)

  for bundle in a:bundles
    if s:sync(a:bang, bundle, i, max)
      call add(_, bundle)
    endif

    let i += 1
  endfor

  return _
endfunction

function! s:check_really_clean(dirs)
  echo join(a:dirs, "\n")

  return input('Are you sure you want to remove '
        \        .len(a:dirs).' bundles? [y/n] : ') =~? 'y'
endfunction

function! s:log(msg)
  if &filetype == 'unite'
    call unite#print_message(a:msg)
  else
    echo a:msg
  endif
endfunction

function! s:error(msg)
  if &filetype == 'unite'
    call unite#print_error(a:msg)
    return
  endif

  for msg in type(a:msg) == type([]) ?
        \ a:msg : split(a:msg, '\n')
    echohl WarningMsg | echomsg msg | echohl None
  endfor
endfunction
