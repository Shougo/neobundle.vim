"=============================================================================
" FILE: neobundle/install.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 27 Sep 2012.
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

" Variables  "{{{
call unite#util#set_default(
      \ 'g:unite_source_neobundle_install_max_processes', 5)
"}}}

function! unite#sources#neobundle_install#define()"{{{
  return unite#util#has_vimproc() ?
        \ [s:source_install, s:source_update] : {}
endfunction"}}}

let s:source_install = {
      \ 'name' : 'neobundle/install',
      \ 'description' : 'install bundles',
      \ 'hooks' : {},
      \ }

function! s:source_install.hooks.on_init(args, context)"{{{
  let bundle_names = filter(copy(a:args), 'v:val != "!"')
  let a:context.source__bang =
        \ index(a:args, '!') >= 0 || !empty(bundle_names)

  call s:init(a:context, bundle_names)

  if empty(a:context.source__bundles)
    let a:context.is_async = 0
    call neobundle#installer#log(
          \ '[neobundle/install] Bundles not found.', 1)
    call neobundle#installer#log(
          \ '[neobundle/install] You may use wrong bundle name.', 1)
  endif
endfunction"}}}

function! s:source_install.hooks.on_close(args, context)"{{{
  if !empty(a:context.source__processes)
    for process in a:context.source__processes
      call process.proc.waitpid()
    endfor
  endif
endfunction"}}}

function! s:source_install.async_gather_candidates(args, context)"{{{
  if a:context.source__number < a:context.source__max_bundles
    while a:context.source__number < a:context.source__max_bundles
        \ && len(a:context.source__processes) <
        \      g:unite_source_neobundle_install_max_processes
      call s:sync(
            \ a:context.source__bundles[a:context.source__number],
            \ a:context, 0)
    endwhile
  endif

  if !empty(a:context.source__processes)
    for process in a:context.source__processes
      call s:check_output(a:context, process)
    endfor

    " Filter eof processes.
    call filter(a:context.source__processes, '!v:val.eof')

    return []
  endif

  let messages = []
  if empty(a:context.source__synced_bundles)
    let messages += ['[neobundle/install] No new bundles installed.']
  else
    let messages += ['[neobundle/install] Installed/Updated bundles:']
          \ + map(copy(a:context.source__synced_bundles),
          \        'v:val.name')
  endif

  if !empty(a:context.source__errored_bundles)
    let messages += ['[neobundle/install] Errored bundles:']
          \ + map(copy(a:context.source__errored_bundles),
          \        'v:val.name')
    call neobundle#installer#log(
          \ 'Please read error message log by :message command.')
  endif

  call neobundle#installer#log(messages, 1)
  call neobundle#installer#helptags(
        \ a:context.source__synced_bundles)
  call neobundle#config#reload(a:context.source__synced_bundles)

  let a:context.is_async = 0

  " Finish.
  call neobundle#installer#log('[neobundle/install] Completed.', 1)
  return []
endfunction"}}}

function! s:source_install.complete(args, context, arglead, cmdline, cursorpos)"{{{
  return ['!'] +
        \ neobundle#complete_bundles(a:arglead, a:cmdline, a:cursorpos)
endfunction"}}}

let s:source_update = deepcopy(s:source_install)
let s:source_update.name = 'neobundle/update'
let s:source_update.description = 'update bundles'

function! s:source_update.hooks.on_init(args, context)"{{{
  let a:context.source__bang = 1
  call s:init(a:context, a:args)
endfunction"}}}

function! s:init(context, bundle_names)
  let a:context.source__synced_bundles = []
  let a:context.source__errored_bundles = []

  let a:context.source__processes = []

  let a:context.source__number = 0

  let a:context.source__bundles = !a:context.source__bang ?
        \ neobundle#get_not_installed_bundles(a:bundle_names) :
        \ empty(a:bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(a:bundle_names)

  let a:context.source__max_bundles =
        \ len(a:context.source__bundles)

  call neobundle#installer#clear_log()
endfunction

function! s:sync(bundle, context, is_revision)"{{{
  let a:context.source__number += 1

  let [cmd, message] =
        \ neobundle#installer#get_{
        \ a:is_revision ? 'revision_lock' : 'sync'}_command(
        \ a:context.source__bang, a:bundle,
        \ a:context.source__number, a:context.source__max_bundles)
  call neobundle#installer#log('[neobundle/install] ' . message, 1)

  if cmd == ''
    " Skipped.
    return
  endif

  try
    let cwd = getcwd()
    if isdirectory(a:bundle.path)
      " Cd to bundle path.
      lcd `=a:bundle.path`
    endif

    let rev = neobundle#installer#get_revision_number(a:bundle)

    let process = {
          \ 'proc' : vimproc#pgroup_open(vimproc#util#iconv(
          \            cmd, &encoding, 'char'), 0, 2),
          \ 'number' : a:context.source__number,
          \ 'revision_locked' : a:is_revision,
          \ 'rev' : rev,
          \ 'bundle' : a:bundle,
          \ 'output' : '',
          \ 'eof' : 0,
          \ }
  finally
    lcd `=cwd`
  endtry

  " Close handles.
  call process.proc.stdin.close()
  call process.proc.stderr.close()

  call add(a:context.source__processes, process)
endfunction"}}}

function! s:check_output(context, process)"{{{
  let a:process.output .= vimproc#util#iconv(
        \ a:process.proc.stdout.read(-1, 300), 'char', &encoding)
  if !a:process.proc.stdout.eof
    return
  endif

  let [cond, status] = a:process.proc.waitpid()
  let num = a:process.number
  let max = a:context.source__max_bundles
  let bundle = a:process.bundle

  let cwd = getcwd()
  try
    let rev = neobundle#installer#get_revision_number(bundle)
  catch
    call neobundle#installer#log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Error'), 1)
    call neobundle#installer#error(bundle.path)
    call neobundle#installer#error(v:throwpoint)
    call neobundle#installer#error(v:exception)
    call neobundle#installer#error('Your repository path may be wrong.')
    call add(a:context.source__errored_bundles,
          \ bundle)

    let a:process.eof = 1

    return
  finally
    lcd `=cwd`
  endtry

  if status && a:process.rev ==# rev
        \ && (bundle.type !=# 'git' ||
        \     a:process.output !~# 'up-to-date\|up to date')
    call neobundle#installer#log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Error'), 1)
    call neobundle#installer#error(bundle.path)
    call neobundle#installer#error(
          \ split(a:process.output, '\n'))
    call add(a:context.source__errored_bundles,
          \ bundle)
  elseif a:process.revision_locked
    call neobundle#installer#log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Locked'), 1)
  elseif a:process.rev ==# rev
    call neobundle#installer#log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Skipped'), 1)
  else
    call neobundle#installer#update_log(
          \ printf('[neobundle/install] (%'.len(max).'d/%d): |%s| %s',
          \ num, max, bundle.name, 'Updated'), 1)
    let message = neobundle#installer#get_updated_log_message(
          \ bundle, rev, a:process.rev)
    call neobundle#installer#update_log('[neobundle/install] ' . message, 1)

    call neobundle#installer#build(bundle)
    call add(a:context.source__synced_bundles,
          \ bundle)
  endif

  if get(bundle, 'rev', '') != ''
        \ && !a:process.revision_locked
    " Lock revision.
    let a:context.source__number -= 1
    call s:sync(bundle, a:context, 1)
    return
  endif

  let a:process.eof = 1
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
