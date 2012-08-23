"=============================================================================
" FILE: installer.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 23 Aug 2012.
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

let s:is_windows = has('win16') || has('win32') || has('win64')
let s:is_cygwin = has('win32unix')
let s:is_mac = !s:is_windows
      \ && (has('mac') || has('macunix') || has('gui_macvim') ||
      \   (!executable('xdg-open') && system('uname') =~? '^darwin'))

let g:neobundle_rm_command =
      \ get(g:, 'neobundle_rm_command',
      \ neobundle#util#is_windows() ? 'rmdir /S /Q' : 'rm -rf')

let s:log = []

function! neobundle#installer#install(bang, ...)
  let bundle_dir = neobundle#get_neobundle_dir()
  if !isdirectory(bundle_dir)
    call mkdir(bundle_dir, 'p')
  endif

  let bundle_names = a:1 == '' ? [] : [ a:1 ]

  let bundles = !a:bang ?
        \ neobundle#get_not_installed_bundles(bundle_names) :
        \ empty(bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(bundle_names)

  call neobundle#installer#clear_log()
  let [installed, errored] = s:install(a:bang, bundles)
  if !has('vim_starting')
    redraw!
  endif

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
endfunction

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

function! neobundle#installer#build(bundle)
  " Environment check.
  let build = get(a:bundle, 'build', {})
  if s:is_windows && has_key(build, 'windows')
    let cmd = build.windows
  elseif s:is_mac && has_key(build, 'mac')
    let cmd = build.mac
  elseif s:is_mac && has_key(build, 'cygwin')
    let cmd = build.cygwin
  elseif !s:is_windows && has_key(build, 'unix')
    let cmd = build.unix
  elseif has_key(build, 'others')
    let cmd = build.others
  else
    return
  endif

  call neobundle#installer#log('Building...')

  let cwd = getcwd()
  try
    if isdirectory(a:bundle.path)
      lcd `=a:bundle.path`
    endif

    let result = neobundle#util#system(cmd)
  finally
    lcd `=cwd`
  endtry

  if neobundle#util#get_last_status()
    call neobundle#installer#error(result)
  else
    call neobundle#installer#log(result)
  endif

  return neobundle#util#get_last_status()
endfunction

function! neobundle#installer#clean(bang, ...)
  let bundle_dirs = map(copy(neobundle#config#get_neobundles()), 'v:val.path')
  let all_dirs = split(neobundle#util#substitute_path_separator(
        \ globpath(neobundle#get_neobundle_dir(), '*')), "\n")
  if get(a:000, 0, '') == ''
    let x_dirs = filter(all_dirs,
          \ "index(bundle_dirs, v:val) < 0 && v:val !~ '/neobundle.vim$'")
  else
    let x_dirs = map(neobundle#config#search(a:000), 'v:val.path')
  endif

  if empty(x_dirs)
    call neobundle#installer#log("All clean!")
    return
  end

  if a:bang || s:check_really_clean(x_dirs)
    if !has('vim_starting')
      redraw
    endif
    let result = system(g:neobundle_rm_command . ' ' .
          \ join(map(x_dirs, '"\"" . v:val . "\""'), ' '))
    if neobundle#util#get_last_status()
      call neobundle#installer#error(result)
    endif

    for dir in x_dirs
      call neobundle#config#rm_bundle(dir)
    endfor
  endif
endfunction

function! neobundle#installer#get_sync_command(bang, bundle, number, max)
  let types = neobundle#config#get_types()
  if !has_key(types, a:bundle.type)
    return ['', printf('(%'.len(a:max).'d/%d): |%s| %s',
          \ a:number, a:max, a:bundle.name, 'Unknown Type')]
  endif

  let cmd = types[a:bundle.type].get_sync_command(a:bundle)

  if cmd == '' || (isdirectory(a:bundle.path) && !a:bang)
    return ['', printf('(%'.len(a:max).'d/%d): |%s| %s',
          \ a:number, a:max, a:bundle.name, 'Skipped')]
  endif

  let message = printf('(%'.len(a:max).'d/%d): |%s| %s',
        \ a:number, a:max, a:bundle.name, cmd)

  return [cmd, message]
endfunction
function! neobundle#installer#get_revision_lock_command(bang, bundle, number, max)
  let repo_dir = neobundle#util#substitute_path_separator(
        \ neobundle#util#expand(a:bundle.path.'/.'.a:bundle.type.'/'))

  let types = neobundle#config#get_types()
  if !has_key(types, a:bundle.type)
    return ['', printf('(%'.len(a:max).'d/%d): |%s| %s',
          \ a:number, a:max, a:bundle.name, 'Unknown Type')]
  endif

  let cmd = types[a:bundle.type].get_revision_lock_command(a:bundle)

  if cmd == ''
    return ['', printf('(%'.len(a:max).'d/%d): |%s| %s',
          \ a:number, a:max, a:bundle.name, 'Skipped')]
  endif

  let message = printf('(%'.len(a:max).'d/%d): |%s| %s',
        \ a:number, a:max, a:bundle.name, cmd)

  return [cmd, message]
endfunction

function! s:sync(bang, bundle, number, max, is_revision)
  let [cmd, message] =
        \ neobundle#installer#get_{a:is_revision ?
        \   'revision_lock' : 'sync'}_command(
        \ a:bang, a:bundle, a:number, a:max)

  if !has('vim_starting')
    redraw
  endif
  call neobundle#installer#log(message)
  if cmd == ''
    " Skipped.
    return 0
  endif

  let types = neobundle#config#get_types()
  let rev_cmd = types[a:bundle.type].get_revision_number_command(a:bundle)

  let cwd = getcwd()
  try
    if isdirectory(a:bundle.path)
      " Cd to bundle path.
      lcd `=a:bundle.path`
      let old_rev = neobundle#util#system(rev_cmd)
    else
      let old_rev = ''
    endif

    let result = neobundle#util#system(cmd)
    let status = neobundle#util#get_last_status()

    let new_rev = neobundle#util#system(rev_cmd)
  finally
    lcd `=cwd`
  endtry

  if status && old_rev ==# new_rev
        \ && (a:bundle.type !=# 'git'
        \    || result !~# 'up-to-date\|up to date')
    call neobundle#installer#error(a:bundle.path)
    call neobundle#installer#error(result)
    return -1
  endif

  if !a:is_revision && get(a:bundle, 'rev', '') != ''
    " Lock revision.
    call s:sync(a:bang, a:bundle, a:number, a:max, 1)
  endif

  if old_rev !=# new_rev
    call neobundle#installer#log(
          \ printf('(%'.len(a:max).'d/%d): |%s| %s %s -> %s',
          \ a:number, a:max, a:bundle.name,
          \ 'Updated', old_rev, new_rev))
  endif

  return old_rev == '' || old_rev !=# new_rev
endfunction

function! s:install(bang, bundles)
  let i = 1
  let [installed, errored] = [[], []]
  let max = len(a:bundles)

  for bundle in a:bundles
    let _ = s:sync(a:bang, bundle, i, max, 0)

    if get(bundle, 'rev', '') != ''
      call s:sync(a:bang, bundle, i, max, 1)
    endif

    if _ > 0
      call add(installed, bundle)
      call neobundle#installer#build(bundle)
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
        \ a:msg : split(a:msg, '\r\?\n')
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

let &cpo = s:save_cpo
unlet s:save_cpo
