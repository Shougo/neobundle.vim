"=============================================================================
" FILE: installer.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
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
" Version: 0.1, for Vim 7.2
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

call neobundle#util#set_default(
      \ 'g:neobundle#rm_command',
      \ (neobundle#util#is_windows() ? 'rmdir /S /Q' : 'rm -rf'),
      \ 'g:neobundle_rm_command')

let s:log = []
let s:updates_log = []

function! neobundle#installer#install(bang, bundle_names)
  let bundle_dir = neobundle#get_neobundle_dir()
  if !isdirectory(bundle_dir)
    call mkdir(bundle_dir, 'p')
  endif

  let bundle_names = split(a:bundle_names)

  let bundles = !a:bang ?
        \ neobundle#get_not_installed_bundles(bundle_names) :
        \ empty(bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#fuzzy_search(bundle_names)
  if empty(bundles)
    call neobundle#installer#error(
          \ '[neobundle/install] Bundles not found.')
    call neobundle#installer#error(
          \ '[neobundle/install] You may use wrong bundle name.')
    return
  endif

  call neobundle#installer#clear_log()
  let [installed, errored] = s:install(a:bang, bundles)
  if !has('vim_starting')
    redraw!
  endif

  call neobundle#installer#log(
        \ "[neobundle/install] Installed/Updated bundles:\n".
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
  if neobundle#util#is_windows() && has_key(build, 'windows')
    let cmd = build.windows
  elseif neobundle#util#is_mac() && has_key(build, 'mac')
    let cmd = build.mac
  elseif neobundle#util#is_cygwin() && has_key(build, 'cygwin')
    let cmd = build.cygwin
  elseif !neobundle#util#is_windows() && has_key(build, 'unix')
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
    let result = system(g:neobundle#rm_command . ' ' .
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

  let is_directory = isdirectory(a:bundle.path)

  let cmd = types[a:bundle.type].get_sync_command(a:bundle)

  if cmd == '' || (is_directory && !a:bang)
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

function! neobundle#installer#get_revision_number(bundle)
  let cwd = getcwd()
  try
    let type = neobundle#config#get_types()[a:bundle.type]

    if !isdirectory(a:bundle.path)
      return ''
    endif

    lcd `=a:bundle.path`

    let rev_cmd = type.get_revision_number_command(a:bundle)

    let rev = substitute(neobundle#util#system(rev_cmd), '\n$', '', '')

    return rev
  finally
    lcd `=cwd`
  endtry
endfunction

function! neobundle#installer#get_updated_log_message(bundle, new_rev, old_rev)
  let cwd = getcwd()
  try
    let type = neobundle#config#get_types()[a:bundle.type]

    if isdirectory(a:bundle.path)
      lcd `=a:bundle.path`
    endif

    let log_command = has_key(type, 'get_log_command') ?
          \ type.get_log_command(a:bundle, a:new_rev, a:old_rev) : ''
    let log = (log_command != '' ?
          \ neobundle#util#system(log_command) : '')
    return log != '' ? log : printf('%s -> %s', a:old_rev, a:new_rev)
  finally
    lcd `=cwd`
  endtry
endfunction

function! s:sync(bang, bundle, number, max)
  let [cmd, message] =
        \ neobundle#installer#get_sync_command(
        \ a:bang, a:bundle, a:number, a:max)

  if !has('vim_starting')
    redraw
  endif
  call neobundle#installer#log(message)
  if cmd == ''
    " Skipped.
    return 0
  elseif cmd =~# '^E: '
    " Errored.
    call neobundle#installer#error(a:bundle.path)
    call neobundle#installer#error(cmd[3:])
    return -1
  endif

  let cwd = getcwd()
  try
    if isdirectory(a:bundle.path)
      " Cd to bundle path.
      lcd `=a:bundle.path`
    endif

    let old_rev = neobundle#installer#get_revision_number(a:bundle)

    let result = neobundle#util#system(cmd)
    let status = neobundle#util#get_last_status()

    if get(a:bundle, 'rev', '') != ''
      " Lock revision.
      call s:lock_revision(a:bang, a:bundle, a:number, a:max)
    endif

    let new_rev = neobundle#installer#get_revision_number(a:bundle)
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

  if old_rev !=# new_rev
    let message = neobundle#installer#get_updated_log_message(
          \ a:bundle, new_rev, old_rev)
    " Use log command.
    call neobundle#installer#update_log(
          \ printf('(%'.len(a:max).'d/%d): |%s| %s',
          \ a:number, a:max, a:bundle.name, 'Updated'))
    call neobundle#installer#update_log(message)
  endif

  return old_rev == '' || old_rev !=# new_rev
endfunction

function! s:lock_revision(bang, bundle, number, max)
  let [cmd, message] =
        \ neobundle#installer#get_revision_lock_command(
        \ a:bang, a:bundle, a:number, a:max)

  if !has('vim_starting')
    redraw
  endif

  if cmd == ''
    " Skipped.
    return 0
  elseif cmd =~# '^E: '
    " Errored.
    call neobundle#installer#error(a:bundle.path)
    call neobundle#installer#error(cmd[3:])
    return -1
  endif

  call neobundle#installer#log(message)

  let cwd = getcwd()
  try
    if isdirectory(a:bundle.path)
      " Cd to bundle path.
      lcd `=a:bundle.path`
    endif

    let result = neobundle#util#system(cmd)
    let status = neobundle#util#get_last_status()
  finally
    lcd `=cwd`
  endtry

  if status
    call neobundle#installer#error(a:bundle.path)
    call neobundle#installer#error(result)
    return -1
  endif
endfunction

function! s:install(bang, bundles)
  let i = 1
  let [installed, errored] = [[], []]
  let max = len(a:bundles)

  for bundle in a:bundles
    let _ = s:sync(a:bang, bundle, i, max)

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

  if g:neobundle#log_filename != ''
    " Appends to log file.
    if filereadable(g:neobundle#log_filename)
      let msg = readfile(g:neobundle#log_filename) + msg
    endif
    call writefile(msg, g:neobundle#log_filename)
  endif
endfunction

function! neobundle#installer#update_log(msg, ...)
  let msgs = []
  for msg in type(a:msg) == type([]) ?
        \ a:msg : [a:msg]
    let source_name = matchstr(msg, '^\[.\{-}\] ')

    let msg_nrs = split(msg, '\n')
    let msgs += [msg_nrs[0]] +
          \ map(msg_nrs[1:], "source_name . v:val")
  endfor

  call call('neobundle#installer#log', [msgs] + a:000)

  let s:updates_log += msgs
endfunction

function! neobundle#installer#error(msg, ...)
  let is_unite = get(a:000, 0, 0)
  let msg = type(a:msg) == type([]) ?
        \ a:msg : split(a:msg, '\r\?\n')
  call extend(s:log, msg)
  call extend(s:updates_log, msg)

  if &filetype == 'unite' || is_unite
    call unite#print_error(msg)
  else
    echohl WarningMsg | echomsg join(msg, "\n") | echohl None
  endif
endfunction

function! neobundle#installer#get_log()
  return s:log
endfunction

function! neobundle#installer#get_updates_log()
  return s:updates_log
endfunction

function! neobundle#installer#clear_log()
  let s:log = []
  let s:updates_log = []

  if g:neobundle#log_filename != ''
        \ && filereadable(g:neobundle#log_filename)
    " Delete log file.
    call delete(g:neobundle#log_filename)
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
