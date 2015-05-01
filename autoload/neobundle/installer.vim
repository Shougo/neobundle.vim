"=============================================================================
" FILE: installer.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
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

let s:install_info_version = '3.0'

let s:log = []
let s:updates_log = []

function! neobundle#installer#update(bundles)
  if neobundle#util#is_sudo()
    call neobundle#util#print_error(
          \ '"sudo vim" is detected. This feature is disabled.')
    return
  endif

  let all_bundles = neobundle#config#get_neobundles()

  call neobundle#commands#helptags(all_bundles)
  call s:reload(filter(copy(a:bundles),
        \ "v:val.sourced && !v:val.disabled && v:val.rtp != ''"))

  call s:save_install_info(all_bundles)

  let lazy_bundles = filter(copy(all_bundles), 'v:val.lazy')
  call neobundle#util#copy_bundle_files(
        \ lazy_bundles, 'ftdetect')
  call neobundle#util#copy_bundle_files(
        \ lazy_bundles, 'after/ftdetect')
endfunction

function! neobundle#installer#build(bundle)
  if !empty(a:bundle.build_commands)
        \ && neobundle#config#check_commands(a:bundle.build_commands)
      call neobundle#installer#log(
            \ printf('[neobundle/install] |%s| ' .
            \        'Build dependencies not met. Skipped', a:bundle.name))
      return 0
  endif

  " Environment check.
  let build = get(a:bundle, 'build', {})
  if neobundle#util#is_windows() && has_key(build, 'windows')
    let cmd = build.windows
  elseif neobundle#util#is_mac() && has_key(build, 'mac')
    let cmd = build.mac
  elseif neobundle#util#is_cygwin() && has_key(build, 'cygwin')
    let cmd = build.cygwin
  elseif !neobundle#util#is_windows() && has_key(build, 'linux')
        \ && !executable('gmake')
    let cmd = build.linux
  elseif !neobundle#util#is_windows() && has_key(build, 'unix')
    let cmd = build.unix
  elseif has_key(build, 'others')
    let cmd = build.others
  else
    return 0
  endif

  call neobundle#installer#log('[neobundle/install] Building...')

  let cwd = getcwd()
  try
    if isdirectory(a:bundle.path)
      call neobundle#util#cd(a:bundle.path)
    endif

    let result = neobundle#util#system(cmd)
  catch
    " Build error from vimproc.
    let message = (v:exception !~# '^Vim:')?
          \ v:exception : v:exception . ' ' . v:throwpoint
    call neobundle#installer#error(message)

    return 1
  finally
    if isdirectory(cwd)
      call neobundle#util#cd(cwd)
    endif
  endtry

  if neobundle#util#get_last_status()
    call neobundle#installer#error(result)
  else
    call neobundle#installer#log('[neobundle/install] ' . result)
  endif

  return neobundle#util#get_last_status()
endfunction

function! neobundle#installer#reinstall(bundles)
  for bundle in a:bundles
    " Reinstall.
    call neobundle#installer#log(
          \ printf('[neobundle/install] |%s| Reinstalling...', bundle.name))

    " Save info.
    let arg = copy(bundle.orig_arg)

    " Remove.
    call neobundle#commands#clean(1, bundle.name)

    call call('neobundle#parser#bundle', [arg])
  endfor

  call s:save_install_info(neobundle#config#get_neobundles())

  " Install.
  call neobundle#commands#install(0,
        \ join(map(copy(a:bundles), 'v:val.name')))

  call neobundle#installer#update(a:bundles)
endfunction

function! neobundle#installer#get_reinstall_bundles(bundles)
  call neobundle#installer#_load_install_info(a:bundles)

  let reinstall_bundles = filter(copy(a:bundles),
        \ "neobundle#config#is_installed(v:val.name)
        \  && v:val.normalized_name !=# 'neobundle' &&
        \     v:val.normalized_name !=# 'unite'
        \  && v:val.type !=# 'nosync'
        \  && !v:val.local &&
        \     v:val.path ==# v:val.installed_path &&
        \     v:val.uri !=# v:val.installed_uri")
  if !empty(reinstall_bundles)
    call neobundle#util#print_error(
          \ '[neobundle] Reinstall bundles are detected!')

    for bundle in reinstall_bundles
      echomsg printf('%s: %s -> %s',
            \   bundle.name, bundle.installed_uri, bundle.uri)
    endfor

    let cwd = neobundle#util#substitute_path_separator(getcwd())
    let warning_bundles = map(filter(copy(reinstall_bundles),
        \     'v:val.path ==# cwd'), 'v:val.path')
    if !empty(warning_bundles)
      call neobundle#util#print_error('Warning: current directory is the
            \ reinstall bundles directory! ' . string(warning_bundles))
    endif
    let ret = confirm('Reinstall bundles now?', "yes\nNo", 2)
    redraw
    if ret != 1
      return []
    endif
  endif

  return reinstall_bundles
endfunction

function! neobundle#installer#get_sync_command(bang, bundle, number, max)
  let type = neobundle#config#get_types(a:bundle.type)
  if empty(type)
    return ['E: Unknown Type', '']
  endif

  let is_directory = isdirectory(a:bundle.path)

  let cmd = type.get_sync_command(a:bundle)

  if cmd == ''
    return ['', 'Not supported sync action.']
  elseif (is_directory && !a:bang)
    return ['', 'Already installed.']
  endif

  let message = printf('(%'.len(a:max).'d/%d): |%s| %s',
        \ a:number, a:max, a:bundle.name, cmd)

  return [cmd, message]
endfunction

function! neobundle#installer#get_revision_lock_command(bang, bundle, number, max)
  let type = neobundle#config#get_types(a:bundle.type)
  if empty(type)
    return ['E: Unknown Type', '']
  endif

  let cmd = type.get_revision_lock_command(a:bundle)

  if cmd == ''
    return ['', '']
  endif

  return [cmd, '']
endfunction

function! neobundle#installer#get_revision_number(bundle)
  let cwd = getcwd()
  let type = neobundle#config#get_types(a:bundle.type)

  if !isdirectory(a:bundle.path)
        \ || !has_key(type, 'get_revision_number_command')
    return ''
  endif

  let cmd = type.get_revision_number_command(a:bundle)
  if cmd == ''
    return ''
  endif

  try
    call neobundle#util#cd(a:bundle.path)

    let rev = neobundle#util#system(cmd)

    " If rev contains spaces, it is error message
    return (rev !~ '\s') ? rev : ''
  finally
    if isdirectory(cwd)
      call neobundle#util#cd(cwd)
    endif
  endtry
endfunction

function! s:get_commit_date(bundle)
  let cwd = getcwd()
  try
    let type = neobundle#config#get_types(a:bundle.type)

    if !isdirectory(a:bundle.path) ||
          \ !has_key(type, 'get_commit_date_command')
      return 0
    endif

    call neobundle#util#cd(a:bundle.path)

    return neobundle#util#system(
          \ type.get_commit_date_command(a:bundle))
  finally
    if isdirectory(cwd)
      call neobundle#util#cd(cwd)
    endif
  endtry
endfunction

function! neobundle#installer#get_updated_log_message(bundle, new_rev, old_rev)
  let cwd = getcwd()
  try
    let type = neobundle#config#get_types(a:bundle.type)

    if isdirectory(a:bundle.path)
      call neobundle#util#cd(a:bundle.path)
    endif

    let log_command = has_key(type, 'get_log_command') ?
          \ type.get_log_command(a:bundle, a:new_rev, a:old_rev) : ''
    let log = (log_command != '' ?
          \ neobundle#util#system(log_command) : '')
    return log != '' ? log : printf('%s -> %s', a:old_rev, a:new_rev)
  finally
    if isdirectory(cwd)
      call neobundle#util#cd(cwd)
    endif
  endtry
endfunction

function! neobundle#installer#sync(bundle, context, is_unite)
  let a:context.source__number += 1

  let num = a:context.source__number
  let max = a:context.source__max_bundles

  let before_one_day = localtime() - 60 * 60 * 24
  let before_one_week = localtime() - 60 * 60 * 24 * 7

  if a:context.source__bang == 1 &&
        \ a:bundle.stay_same
    let [cmd, message] = ['', 'has "stay_same" attribute.']
  elseif a:context.source__bang == 1 &&
        \ a:bundle.uri ==# a:bundle.installed_uri &&
        \ a:bundle.updated_time < before_one_week
        \     && a:bundle.checked_time >= before_one_day
    let [cmd, message] = ['', 'Outdated plugin.']
  else
    let [cmd, message] =
          \ neobundle#installer#get_sync_command(
          \ a:context.source__bang, a:bundle,
          \ a:context.source__number, a:context.source__max_bundles)
  endif

  if cmd == ''
    " Skipped.
    call neobundle#installer#log(s:get_skipped_message(
          \ num, max, a:bundle, '[neobundle/install]', message), a:is_unite)
    return
  elseif cmd =~# '^E: '
    " Errored.

    call neobundle#installer#update_log(
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
    let lang_save = $LANG
    let $LANG = 'C'

    if isdirectory(a:bundle.path)
      " Cd to bundle path.
      call neobundle#util#cd(a:bundle.path)
    endif

    let rev = neobundle#installer#get_revision_number(a:bundle)

    let process = {
          \ 'number' : num,
          \ 'rev' : rev,
          \ 'bundle' : a:bundle,
          \ 'output' : '',
          \ 'status' : -1,
          \ 'eof' : 0,
          \ 'start_time' : localtime(),
          \ }

    if isdirectory(a:bundle.path)
          \ && (a:bundle.rev != '' || !a:bundle.local)
      let rev_save = a:bundle.rev
      try
        " Checkout HEAD revision.
        let a:bundle.rev = ''

        call neobundle#installer#lock_revision(
              \ process, a:context, a:is_unite)
      finally
        let a:bundle.rev = rev_save
      endtry
    endif

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
    let $LANG = lang_save
    if isdirectory(cwd)
      call neobundle#util#cd(cwd)
    endif
  endtry

  call add(a:context.source__processes, process)
endfunction

function! neobundle#installer#check_output(context, process, is_unite)
  if neobundle#util#has_vimproc() && has_key(a:process, 'proc')
    let is_timeout = (localtime() - a:process.start_time)
          \             >= a:process.bundle.install_process_timeout
    let a:process.output .= vimproc#util#iconv(
          \ a:process.proc.stdout.read(-1, 300), 'char', &encoding)
    if !a:process.proc.stdout.eof && !is_timeout
      return
    endif
    call a:process.proc.stdout.close()

    let status = a:process.proc.waitpid()[1]
  else
    let is_timeout = 0
    let status = a:process.status
  endif

  let num = a:process.number
  let max = a:context.source__max_bundles
  let bundle = a:process.bundle

  if bundle.rev != '' || !a:context.source__bang
    " Lock revision.
    let rev_save = bundle.rev
    try
      if !a:context.source__bang && bundle.rev == ''
        " Checkout install_rev revision.
        let bundle.rev = bundle.install_rev
      endif

      call neobundle#installer#lock_revision(
            \ a:process, a:context, a:is_unite)
    finally
      let bundle.rev = rev_save
    endtry
  endif

  let rev = neobundle#installer#get_revision_number(bundle)

  let updated_time = s:get_commit_date(bundle)
  let bundle.checked_time = localtime()

  let is_failed = is_timeout
        \ || (status && a:process.rev ==# rev
        \     && (bundle.type !=# 'git'
        \         || a:process.output !~# 'up-to-date\|up to date'))

  let build_failed = is_failed ? 0 : neobundle#installer#build(bundle)

  if is_failed || build_failed
    let message = printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Error')
    call neobundle#installer#update_log(message, a:is_unite)
    call neobundle#installer#error(bundle.path, a:is_unite)

    if build_failed
      if confirm('Build failed. Uninstall "'
            \ .bundle.name.'" now?', "yes\nNo", 2) == 1
        " Remove.
        call neobundle#commands#clean(1, bundle.name)
      endif
    endif

    call neobundle#installer#error(
          \ (is_timeout ? 'Process timeout.' :
          \    split(a:process.output, '\n')), a:is_unite)

    call add(a:context.source__errored_bundles,
          \ bundle)
  elseif a:process.rev ==# rev
    if updated_time != 0
      let bundle.updated_time = updated_time
    endif

    call neobundle#installer#log(s:get_skipped_message(
          \ num, max, bundle, '[neobundle/install]',
          \ 'Same revision.'), a:is_unite)
  else
    call neobundle#installer#update_log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Updated'), a:is_unite)
    let message = neobundle#installer#get_updated_log_message(
          \ bundle, rev, a:process.rev)
    call neobundle#installer#update_log(
          \ map(split(message, '\n'),
          \ "printf('[neobundle/install] |%s| ' .
          \   substitute(v:val, '%', '%%', 'g'), bundle.name)"),
          \ a:is_unite)

    if updated_time == 0
      let updated_time = bundle.checked_time
    endif
    let bundle.updated_time = updated_time
    let bundle.installed_uri = bundle.uri
    let bundle.revisions[updated_time] = rev

    if neobundle#config#is_sourced(bundle.name)
      " Already sourced.
      call neobundle#config#rtp_add(bundle)
    endif

    call add(a:context.source__synced_bundles,
          \ bundle)
  endif

  let a:process.eof = 1
endfunction

function! neobundle#installer#lock_revision(process, context, is_unite)
  let num = a:process.number
  let max = a:context.source__max_bundles
  let bundle = a:process.bundle

  let bundle.new_rev = neobundle#installer#get_revision_number(bundle)

  let [cmd, message] =
        \ neobundle#installer#get_revision_lock_command(
        \ a:context.source__bang, bundle, num, max)

  if cmd == ''
    " Skipped.
    return 0
  elseif cmd =~# '^E: '
    " Errored.
    call neobundle#installer#error(bundle.path, a:is_unite)
    call neobundle#installer#error(cmd[3:], a:is_unite)
    return -1
  endif

  if bundle.rev != ''
    call neobundle#installer#log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Locked'), a:is_unite)

    call neobundle#installer#log(
          \ '[neobundle/install] ' . message, a:is_unite)
  endif

  let cwd = getcwd()
  try
    if isdirectory(bundle.path)
      " Cd to bundle path.
      call neobundle#util#cd(bundle.path)
    endif

    let result = neobundle#util#system(cmd)
    let status = neobundle#util#get_last_status()
  finally
    if isdirectory(cwd)
      call neobundle#util#cd(cwd)
    endif
  endtry

  if status
    call neobundle#installer#error(bundle.path, a:is_unite)
    call neobundle#installer#error(result, a:is_unite)
    return -1
  endif
endfunction

function! s:save_install_info(bundles)
  let s:install_info = {}
  for bundle in filter(copy(a:bundles),
        \ "!v:val.local && has_key(v:val, 'updated_time')")
    " Note: Don't save local repository.
    let s:install_info[bundle.name] = {
          \   'checked_time' : bundle.checked_time,
          \   'updated_time' : bundle.updated_time,
          \   'installed_uri' : bundle.installed_uri,
          \   'installed_path' : bundle.path,
          \   'revisions' : bundle.revisions,
          \ }
  endfor

  call neobundle#util#writefile('install_info',
        \ [s:install_info_version, string(s:install_info)])

  " Save lock file
  call s:save_lockfile(a:bundles)
endfunction

function! neobundle#installer#_load_install_info(bundles)
  let install_info_path =
        \ neobundle#get_neobundle_dir() . '/.neobundle/install_info'
  if !exists('s:install_info')
    call s:source_lockfile()

    let s:install_info = {}

    if filereadable(install_info_path)
      try
        let list = readfile(install_info_path)
        let ver = list[0]
        sandbox let s:install_info = eval(list[1])
        if ver !=# s:install_info_version
              \ || type(s:install_info) != type({})
          let s:install_info = {}
        endif
      catch
      endtry
    endif
  endif

  call map(a:bundles, "extend(v:val, get(s:install_info, v:val.name, {
        \ 'checked_time' : localtime(),
        \ 'updated_time' : localtime(),
        \ 'installed_uri' : v:val.uri,
        \ 'installed_path' : v:val.path,
        \ 'revisions' : {},
        \}))")

  return s:install_info
endfunction

function! s:get_skipped_message(number, max, bundle, prefix, message)
  let messages = [a:prefix . printf(' (%'.len(a:max).'d/%d): |%s| %s',
          \ a:number, a:max, a:bundle.name, 'Skipped')]
  if a:message != ''
    call add(messages, a:prefix . ' ' . a:message)
  endif
  return messages
endfunction

function! neobundle#installer#log(msg, ...)
  let msg = type(a:msg) == type([]) ?
        \ a:msg : split(a:msg, '\n')
  call extend(s:log, msg)

  call s:append_log_file(msg)
endfunction

function! neobundle#installer#update_log(msg, ...)
  let is_unite = get(a:000, 0, 0)
  let msgs = []
  for msg in type(a:msg) == type([]) ?
        \ a:msg : [a:msg]
    let source_name = matchstr(msg, '^\[.\{-}\] ')

    let msg_nrs = split(msg, '\n')
    let msgs += [msg_nrs[0]] +
          \ map(msg_nrs[1:], "source_name . v:val")
  endfor

  if !(&filetype == 'unite' || is_unite)
    call neobundle#util#redraw_echo(msg)
  endif

  call neobundle#installer#log(msgs)

  let s:updates_log += msgs
endfunction

function! neobundle#installer#error(msg, ...)
  let msg = type(a:msg) == type([]) ?
        \ a:msg : split(a:msg, '\r\?\n')
  call extend(s:log, msg)
  call extend(s:updates_log, msg)

  call neobundle#util#print_error(msg)
  call s:append_log_file(msg)
endfunction

function! s:append_log_file(msg)
  if g:neobundle#log_filename == ''
    return
  endif

  let msg = a:msg
  " Appends to log file.
  if filereadable(g:neobundle#log_filename)
    let msg = readfile(g:neobundle#log_filename) + msg
  endif

  let dir = fnamemodify(g:neobundle#log_filename, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  call writefile(msg, g:neobundle#log_filename)
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

function! neobundle#installer#get_progress_message(bundle, number, max)
  return printf('(%'.len(a:max).'d/%d) [%-20s] %s',
          \ a:number, a:max,
          \ repeat('=', (a:number*20/a:max)), a:bundle.name)
endfunction

function! neobundle#installer#get_tags_info()
  let path = neobundle#get_neobundle_dir() . '/.neobundle/tags_info'
  if !filereadable(path)
    return []
  endif

  return readfile(path)
endfunction

function! s:save_lockfile(bundles) "{{{
  let path = neobundle#get_neobundle_dir() . '/NeoBundle.lock'
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif

  return writefile(sort(map(filter(map(copy(a:bundles),
        \ '[v:val.name, neobundle#installer#get_revision_number(v:val)]'),
        \ "v:val[1] != '' && v:val[1] !~ '\s'"),
        \ "printf('NeoBundleLock %s %s',
        \          escape(v:val[0], ' \'), v:val[1])")), path)
endfunction"}}}

function! s:source_lockfile() "{{{
  let path = neobundle#get_neobundle_dir() . '/NeoBundle.lock'
  if filereadable(path)
    execute 'source' fnameescape(path)
  endif
endfunction"}}}

function! s:reload(bundles) "{{{
  if empty(a:bundles)
    return
  endif

  call filter(copy(a:bundles), 'neobundle#config#rtp_add(v:val)')

  silent! runtime! ftdetect/**/*.vim
  silent! runtime! after/ftdetect/**/*.vim
  silent! runtime! plugin/**/*.vim
  silent! runtime! after/plugin/**/*.vim

  " Call hooks.
  call neobundle#call_hook('on_post_source', a:bundles)
endfunction"}}}

function! s:redir(cmd) "{{{
  redir => res
  silent! execute a:cmd
  redir END
  return res
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo
