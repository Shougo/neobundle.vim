"=============================================================================
" FILE: installer.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 27 Mar 2012.
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

let s:save_cpo = &cpo
set cpo&vim

" Create vital module for neobundle
let s:V = vital#of('neobundle.vim')

function! s:system(...)
  return call(s:V.system, a:000, s:V)
endfunction

function! s:get_last_status(...)
  return call(s:V.get_last_status, a:000, s:V)
endfunction

let s:log = []

function! neobundle#installer#install(bang, ...)
  let bundle_dir = neobundle#get_neobundle_dir()
  if !isdirectory(bundle_dir)
    call mkdir(bundle_dir, 'p')
  endif

  let bundles = (a:1 == '') ?
        \ neobundle#config#get_neobundles() :
        \ map(copy(a:000), 'neobundle#config#init_bundle(v:val, {})')
  if !a:bang
    let bundles = filter(copy(bundles),
          \ "!isdirectory(neobundle#util#expand(v:val.path))")
  endif

  call neobundle#installer#clear_log()
  let [installed, errored] = s:install(a:bang, bundles)
  redraw!

  call neobundle#installer#log(
        \ "[neobundle/install] Installed bundles:\n".
        \ join((empty(installed) ?
        \   ['no new bundles installed'] :
        \   map(copy(installed), 'v:val.name')),"\n"))

  if !empty(errored)
    call neobundle#installer#log(
          \ "[neobundle/install] Errored bundles:\n".join(
          \ map(copy(errored), 'v:val.name')), "\n")
    call neobundle#installer#log(
          \ 'Please read error message log by :message command.')
  endif

  call neobundle#installer#helptags(installed)

  call neobundle#config#reload(installed)
endf

function! neobundle#installer#helptags(bundles)
  if empty(a:bundles)
    return
  endif

  let help_dirs = filter(copy(a:bundles), 's:has_doc(v:val.rtp)')

  call map(help_dirs, 's:helptags(v:val.rtp)')
  if !empty(help_dirs)
    call neobundle#installer#log('[neobundle/install] Helptags: done. '
          \ .len(help_dirs).' bundles processed')
  endif
  return help_dirs
endfunction

function! neobundle#installer#clean(bang, ...)
  let bundle_dirs = map(copy(neobundle#config#get_neobundles()), 'v:val.path')
  let all_dirs = split(neobundle#util#substitute_path_separator(
        \ globpath(neobundle#get_neobundle_dir(), '*')), "\n")
  if get(a:000, 0, '') == ''
    let x_dirs = filter(all_dirs, 'index(bundle_dirs, v:val) < 0')
  else
    let x_dirs = map(neobundle#config#search(a:000), 'v:val.path')
  endif

  if empty(x_dirs)
    call neobundle#installer#log("All clean!")
    return
  end

  if a:bang || s:check_really_clean(x_dirs)
    let cmd = neobundle#util#is_windows() ?
          \ 'rmdir /S /Q' : 'rm -rf'
    redraw
    let result = s:system(cmd . ' ' . join(map(x_dirs, '"\"" . v:val . "\""'), ' '))
    if s:get_last_status()
      call neobundle#installer#error(result)
    endif

    for dir in x_dirs
      call neobundle#config#rm_bndle(dir)
    endfor
  endif
endfunction

function! neobundle#installer#get_sync_command(bang, bundle, number, max)
  if !isdirectory(a:bundle.path)
    if a:bundle.type == 'svn'
      let cmd = 'svn checkout'
    elseif a:bundle.type == 'hg'
      let cmd = 'hg clone'
    elseif a:bundle.type == 'git'
      let cmd = 'git clone'
    else
      return ['', printf('(%'.len(a:max).'d/%d): %s',
            \ a:number, a:max, 'Unknown')]
    endif

    let cmd .= printf(' %s "%s"', a:bundle.uri, a:bundle.path)

    let message = printf('(%'.len(a:max).'d/%d): %s',
          \ a:number, a:max, cmd)
  else
    if !a:bang || a:bundle.type ==# 'nosync'
      return ['', printf('(%'.len(a:max).'d/%d): %s',
            \ a:number, a:max, 'Skipped')]
    endif

    if a:bundle.type == 'svn'
      let cmd = 'svn up'
    elseif a:bundle.type == 'hg'
      let cmd = 'hg pull -u'
    elseif a:bundle.type == 'git'
      let cmd = 'git pull --rebase'
    else
      return ['', printf('(%'.len(a:max).'d/%d): %s',
            \ a:number, a:max, 'Unknown')]
    endif

    " Cd to bundle path.
    let path = a:bundle.path
    lcd `=path`

    let message = printf('(%'.len(a:max).'d/%d): %s %s',
          \ a:number, a:max, cmd, path)
  endif

  return [cmd, message]
endfunction
function! neobundle#installer#get_revision_command(bang, bundle, number, max)
  let repo_dir = neobundle#util#substitute_path_separator(
        \ neobundle#util#expand(a:bundle.path.'/.'.a:bundle.type.'/'))

  " Lock revision.
  if a:bundle.type == 'svn'
    let cmd = 'svn up'
  elseif a:bundle.type == 'hg'
    let cmd = 'hg up'
  elseif a:bundle.type == 'git'
    let cmd = 'git checkout'
  else
    return ['', printf('(%'.len(a:max).'d/%d): %s',
          \ a:number, a:max, 'Unknown')]
  endif

  let cmd .= ' ' . a:bundle.rev

  " Cd to bundle path.
  let path = a:bundle.path
  lcd `=path`

  let message = printf('(%'.len(a:max).'d/%d): %s',
        \ a:number, a:max, cmd)

  return [cmd, message]
endfunction

function! s:sync(bang, bundle, number, max, is_revision)
  let cwd = getcwd()

  let [cmd, message] =
        \ neobundle#installer#get_{a:is_revision ? 'revision' : 'sync'}_command(
        \ a:bang, a:bundle, a:number, a:max)

  redraw
  call neobundle#installer#log(message)
  if cmd == ''
    " Skipped.
    return 0
  endif

  let result = s:system(cmd)

  if getcwd() !=# cwd
    lcd `=cwd`
  endif

  if s:get_last_status()
    call neobundle#installer#error(a:bundle.path)
    call neobundle#installer#error(result)
    return -1
  endif

  if !a:is_revision && get(a:bundle, 'rev', '') != ''
    " Lock revision.
    call s:sync(a:bang, a:bundle, a:number, a:max, 1)
  endif

  return result !~# 'up-to-date\|up to date'
endfunction

function! s:install(bang, bundles)
  let i = 1
  let [installed, errored] = [[], []]
  let max = len(a:bundles)

  for bundle in a:bundles
    let _ = s:sync(a:bang, bundle, i, max, 0)
    if _ > 0
      if get(bundle, 'rev', '') != ''
        call s:sync(a:bang, bundle, i, max, 1)
      endif

      call add(installed, bundle)
    elseif _ < 0
      call add(errored, bundle)
    endif

    let i += 1
  endfor

  return [installed, errored]
endfunction

function! s:has_doc(path)
  return isdirectory(a:path.'/doc')
        \   && (!filereadable(a:path.'/doc/tags')
        \       || filewritable(a:path.'/doc/tags'))
        \   && (!filereadable(a:path.'/doc/tags-??')
        \       || filewritable(a:path.'/doc/tags-??'))
        \   && (glob(a:path.'/doc/*.txt') != ''
        \       || glob(a:path.'/doc/*.??x') != '')
endfunction

function! s:helptags(path)
  try
    helptags `=a:path . '/doc/'`
  catch
    call neobundle#installer#error('Error generating helptags in '.a:path)
    call neobundle#installer#error(v:exception . ' ' . v:throwpoint)
  endtry
endfunction

function! s:check_really_clean(dirs)
  echo join(a:dirs, "\n")

  return input('Are you sure you want to remove '
        \        .len(a:dirs).' bundles? [y/n] : ') =~? 'y'
endfunction

function! neobundle#installer#log(msg, ...)
  let is_unite = get(a:000, 0, 0)
  let msg = type(a:msg) == type([]) ?
        \ a:msg : [a:msg]
  call extend(s:log, msg)

  if &filetype == 'unite' || is_unite
    call unite#print_message(msg)
  else
    echo join(msg, "\n")
  endif
endfunction

function! neobundle#installer#error(msg, ...)
  let is_unite = get(a:000, 0, 0)
  let msg = type(a:msg) == type([]) ?
        \ a:msg : [a:msg]
  call extend(s:log, msg)

  if &filetype == 'unite' || is_unite
    call unite#print_error(msg)
  else
    echohl WarningMsg | echomsg join(msg, "\n") | echohl None
  endif
endfunction

function! neobundle#installer#get_log()
  return s:log
endfunction

function! neobundle#installer#clear_log()
  let s:log = []
endfunction

function! neobundle#installer#has_vimproc()
  return call(s:V.has_vimproc, a:000, s:V)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
