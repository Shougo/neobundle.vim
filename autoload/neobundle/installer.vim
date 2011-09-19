"=============================================================================
" FILE: installer.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 19 Sep 2011.
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
        \ map(copy(a:000), 'vundle#config#init_bundle(v:val, {})')

  let installed = s:install(a:bang, bundles)
  redraw!

  call s:log("Installed bundles:\n".join((empty(installed) ?
  \      ['no new bundles installed'] :
  \      map(installed, 'v:val.name')),"\n"))

  call neobundle#installer#helptags(bundles)
endf

function! neobundle#installer#helptags(bundles)
  let help_dirs = filter(a:bundles, 'v:val.has_doc()')
  call map(help_dirs, 'v:val.helptags()')
  if !empty(help_dirs)
    call s:log('Helptags: done. '.len(help_dirs).' bundles processed')
  endif
  return help_dirs
endfunction

function! neobundle#installer#clean(bang)
  let bundle_dirs = map(copy(neobundle#config#get_neobundles()), 'v:val.path')
  let all_dirs = split(globpath(neobundle#get_neobundle_dir(), '*'), "\n")
  let x_dirs = filter(all_dirs, 'index(bundle_dirs, v:val) < 0')

  if empty(x_dirs)
    call s:log("All clean!")
    return
  end

  if a:bang || input('Are you sure you want to remove '
        \        .len(x_dirs).' bundles? [ y/n ]:') =~? 'y'
    let cmd = (has('win32') || has('win64')) ?
    \           'rmdir /S /Q' : 'rm -rf'
    call s:system(cmd . ' ' . join(map(x_dirs, '"\"" . v:val . "\""'), ' '))
  endif
endfunction

function! s:sync(bang, bundle, number, max)
  let cwd = getcwd()
  let git_dir = expand(a:bundle.path.'/.git/')
  if isdirectory(git_dir)
    if !(a:bang) | return 0 | endif
    let cmd = 'git pull'
    "cd to bundle path"
    let path = a:bundle.path
    lcd `=path`

    call s:log(printf('(%d/%d): %s', a:number, a:max, path))
    redraw
  else
    let cmd = 'git clone '.a:bundle.uri.' '.a:bundle.path

    call s:log(printf('(%d/%d): %s', a:number, a:max, cmd))
    redraw
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

  if result =~ 'fatal:'
    call s:V.print_error('Module ' . a:bundle.name . ' doesn''t exists')
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

" TODO: make it pause after output in console mode
function! s:log(msg)
  if &filetype == 'unite'
    call unite#print_message(a:msg)
  else
    echo a:msg
  endif
endfunction
