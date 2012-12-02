"=============================================================================
" FILE: installer.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 02 Dec 2012.
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
call neobundle#util#set_default(
      \ 'g:neobundle#install_max_processes', 5,
      \ 'g:unite_source_neobundle_install_max_processes')

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
  if a:bang == 1 && empty(bundle_names)
    " Remove stay_same bundles.
    call filter(bundles, "!get(v:val, 'stay_same', 0)")
  endif
  if empty(bundles)
    call neobundle#installer#error(
          \ '[neobundle/install] Target bundles not found.')
    call neobundle#installer#error(
          \ '[neobundle/install] You may use wrong bundle name'.
          \ ' or all bundles are already installed.')
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

  call neobundle#installer#log('[neobundle/install] Building...')

  let cwd = getcwd()
  try
    if isdirectory(a:bundle.path)
      lcd `=a:bundle.path`
    endif

    if a:bundle.name ==# 'vimproc' && neobundle#util#is_windows()
          \ && neobundle#util#has_vimproc()
      let result = s:build_vimproc_dll(cmd)
    else
      let result = neobundle#util#system(cmd)
    endif

    let result = substitute(result, '\n$', '', '')
  finally
    if isdirectory(cwd)
      lcd `=cwd`
    endif
  endtry

  if neobundle#util#get_last_status()
    call neobundle#installer#error(result)
  else
    call neobundle#installer#log('[neobundle/install] ' . result)
  endif

  return neobundle#util#get_last_status()
endfunction

function! s:build_vimproc_dll(cmd)
  " Build vimproc in Windows.

  " Save dll name.
  let dll_path = exists('g:vimproc#dll_path') ?
        \ g:vimproc#dll_path : g:vimproc_dll_path

  " Rename dll.
  let temp = tempname()
  call rename(dll_path, temp)

  " Note: Can't use vimproc function.
  let result = system(a:cmd)

  if filereadable(dll_path)
    " Updated. Delete previous dll.
    call delete(temp)
  else
    " Didn't updated. Restore it.
    call rename(temp, dll_path)
  endif

  return result
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
    call neobundle#installer#log('[neobundle/install] All clean!')
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

function! neobundle#installer#reinstall(bundle_names)
  let bundles = neobundle#config#search(split(a:bundle_names))

  if empty(bundles)
    call neobundle#installer#error(
          \ '[neobundle/install] Target bundles not found.')
    call neobundle#installer#error(
          \ '[neobundle/install] You may use wrong bundle name.')
    return
  endif

  for bundle in bundles
    " Save info.
    let arg = bundle.orig_arg

    " Remove.
    call neobundle#installer#clean(1, bundle.name)

    call call('neobundle#config#bundle', [arg])
  endfor

  " Install.
  call neobundle#installer#install(0, '')
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
    if isdirectory(cwd)
      lcd `=cwd`
    endif
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
    if isdirectory(cwd)
      lcd `=cwd`
    endif
  endtry
endfunction

function! neobundle#installer#sync(bundle, context, is_unite)
  let a:context.source__number += 1

  let num = a:context.source__number
  let max = a:context.source__max_bundles

  let [cmd, message] =
        \ neobundle#installer#get_sync_command(
        \ a:context.source__bang, a:bundle,
        \ a:context.source__number, a:context.source__max_bundles)

  if !has('vim_starting') && !a:is_unite
    redraw!
  endif

  if cmd == ''
    " Skipped.
    call neobundle#installer#log(
          \ '[neobundle/install] ' . message, a:is_unite)
    return
  elseif cmd =~# '^E: '
    " Errored.

    call neobundle#installer#log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, a:bundle.name, 'Error'), a:is_unite)
    call neobundle#installer#error(cmd[3:], a:is_unite)
    call add(a:context.source__errored_bundles,
          \ a:bundle)
    return
  endif

  call neobundle#installer#log(
        \ '[neobundle/install] ' . message, a:is_unite)

  let cwd = getcwd()
  try
    if isdirectory(a:bundle.path)
      " Cd to bundle path.
      lcd `=a:bundle.path`
    endif

    let rev = neobundle#installer#get_revision_number(a:bundle)

    let process = {
          \ 'number' : num,
          \ 'rev' : rev,
          \ 'bundle' : a:bundle,
          \ 'output' : '',
          \ 'status' : -1,
          \ 'eof' : 0,
          \ }
    if neobundle#util#has_vimproc()
      let process.proc = vimproc#pgroup_open(vimproc#util#iconv(
            \            cmd, &encoding, 'char'), 0, 2)

      " Close handles.
      call process.proc.stdin.close()
      call process.proc.stderr.close()
    else
      let process.output = neobundle#util#system(cmd)
      let process.status = neobundle#util#get_last_status()
    endif
  finally
    if isdirectory(cwd)
      lcd `=cwd`
    endif
  endtry

  call add(a:context.source__processes, process)
endfunction

function! neobundle#installer#check_output(context, process, is_unite)
  if neobundle#util#has_vimproc()
    let a:process.output .= vimproc#util#iconv(
          \ a:process.proc.stdout.read(-1, 300), 'char', &encoding)
    if !a:process.proc.stdout.eof
      return
    endif

    let [_, status] = a:process.proc.waitpid()
  else
    let status = a:process.status
  endif

  let num = a:process.number
  let max = a:context.source__max_bundles
  let bundle = a:process.bundle

  " Lock revision.
  call neobundle#installer#lock_revision(
        \ a:process, a:context, a:is_unite)

  let cwd = getcwd()

  let rev = neobundle#installer#get_revision_number(bundle)

  if status && a:process.rev ==# rev
        \ && (bundle.type !=# 'git' ||
        \     a:process.output !~# 'up-to-date\|up to date')
    call neobundle#installer#log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Error'), a:is_unite)
    call neobundle#installer#error(bundle.path, a:is_unite)
    call neobundle#installer#error(
          \ split(a:process.output, '\n'), a:is_unite)
    call add(a:context.source__errored_bundles,
          \ bundle)
  elseif a:process.rev ==# rev
    call neobundle#installer#log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Skipped'), a:is_unite)
  else
    call neobundle#installer#update_log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Updated'), a:is_unite)
    let message = neobundle#installer#get_updated_log_message(
          \ bundle, rev, a:process.rev)
    call neobundle#installer#update_log(
          \ '[neobundle/install] ' . message, a:is_unite)

    call neobundle#installer#build(bundle)
    call add(a:context.source__synced_bundles,
          \ bundle)
  endif

  let a:process.eof = 1
endfunction

function! neobundle#installer#lock_revision(process, context, is_unite)
  let num = a:process.number
  let max = a:context.source__max_bundles
  let bundle = a:process.bundle

  let [cmd, message] =
        \ neobundle#installer#get_revision_lock_command(
        \ a:context.source__bang, bundle, num, max)

  if !has('vim_starting') && !a:is_unite
    redraw!
  endif

  if cmd == ''
    " Skipped.
    return 0
  elseif cmd =~# '^E: '
    " Errored.
    call neobundle#installer#error(bundle.path, a:is_unite)
    call neobundle#installer#error(cmd[3:], a:is_unite)
    return -1
  endif

  call neobundle#installer#log(
        \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
        \ num, max, bundle.name, 'Locked'), a:is_unite)

  call neobundle#installer#log(
        \ '[neobundle/install] ' . message, a:is_unite)

  let cwd = getcwd()
  try
    if isdirectory(bundle.path)
      " Cd to bundle path.
      lcd `=bundle.path`
    endif

    let result = neobundle#util#system(cmd)
    let status = neobundle#util#get_last_status()
  finally
    if isdirectory(cwd)
      lcd `=cwd`
    endif
  endtry

  if status
    call neobundle#installer#error(bundle.path, a:is_unite)
    call neobundle#installer#error(result, a:is_unite)
    return -1
  endif
endfunction

function! s:install(bang, bundles)
  " Set context.
  let context = {}
  let context.source__bang = a:bang
  let context.source__synced_bundles = []
  let context.source__errored_bundles = []
  let context.source__processes = []
  let context.source__number = 0
  let context.source__bundles = a:bundles
  let context.source__max_bundles =
        \ len(context.source__bundles)

  while 1
    if context.source__number < context.source__max_bundles
      while context.source__number < context.source__max_bundles
            \ && len(context.source__processes) <
            \      g:neobundle#install_max_processes

        call neobundle#installer#sync(
              \ context.source__bundles[context.source__number],
              \ context, 0)
      endwhile
    endif

    if empty(context.source__processes)
      break
    endif

    for process in context.source__processes
      call neobundle#installer#check_output(context, process, 0)
    endfor

    " Filter eof processes.
    call filter(context.source__processes, '!v:val.eof')
  endwhile

  return [context.source__synced_bundles,
        \ context.source__errored_bundles]
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
        \ a:msg : split(a:msg, '\n')
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
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
