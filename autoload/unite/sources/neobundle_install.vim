"=============================================================================
" FILE: neobundle/install.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
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
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

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
endfunction"}}}
function! s:source_install.hooks.on_close(args, context)"{{{
  if !empty(a:context.source__process)
    call a:context.source__process.waitpid()
  endif
endfunction"}}}

function! s:source_install.gather_candidates(args, context)"{{{
  if empty(a:context.source__bundles)
    let a:context.is_async = 0
    call neobundle#installer#log(
          \ '[neobundle/install] Bundles not found.', 1)
  endif
  return []
endfunction"}}}

function! s:source_install.async_gather_candidates(args, context)"{{{
  if !empty(a:context.source__process)
    call s:check_output(a:context)
    return []
  endif

  if a:context.source__number < a:context.source__max_bundles
    call s:sync(
          \ a:context.source__bundles[a:context.source__number],
          \ a:context, 0)
    return []
  endif

  let messages = []
  if empty(a:context.source__synced_bundles)
    let messages += ['[neobundle/install] No new bundles installed.']
  else
    let messages += ['[neobundle/install] Installed bundles:']
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

  let a:context.source__bundles = empty(a:bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(a:bundle_names)

  let a:context.source__number = 0
  let a:context.source__process = {}
  let a:context.source__output = ''

  if !a:context.source__bang
    let a:context.source__bundles = filter(
          \ copy(a:context.source__bundles),
          \ "!isdirectory(neobundle#util#expand(v:val.path))")
  endif

  let a:context.source__max_bundles =
        \ len(a:context.source__bundles)

  call neobundle#installer#clear_log()
endfunction

function! s:sync(bundle, context, is_revision)"{{{
  let cwd = getcwd()

  let [cmd, message] =
        \ neobundle#installer#get_{a:is_revision ? 'revision' : 'sync'}_command(
        \ a:context.source__bang, a:bundle,
        \ a:context.source__number+1, a:context.source__max_bundles)
  call neobundle#installer#log('[neobundle/install] ' . message, 1)

  if cmd == ''
    " Skipped.
    let a:context.source__process = {}
    let a:context.source__output = ''
    let a:context.source__number += 1
    return
  endif

  let a:context.source__process = vimproc#pgroup_open(cmd, 0, 2)
  let a:context.source__revision_locked = a:is_revision

  " Close handles.
  call a:context.source__process.stdin.close()
  call a:context.source__process.stderr.close()

  if getcwd() !=# cwd
    lcd `=cwd`
  endif
endfunction"}}}

function! s:check_output(context)"{{{
  let stdout = a:context.source__process.stdout
  let a:context.source__output .= stdout.read(-1, 300)
  if stdout.eof
    let [cond, status] = a:context.source__process.waitpid()
    let num = a:context.source__number+1
    let max = a:context.source__max_bundles
    let bundle = a:context.source__bundles[a:context.source__number]

    if status
      call neobundle#installer#log(
            \ printf('[neobundle/install] (%'.len(max).'d/%d): %s',
            \ num, max, 'Error'), 1)
      call neobundle#installer#error(bundle.path)
      call neobundle#installer#error(
            \ split(a:context.source__output, '\n'))
      call add(a:context.source__errored_bundles,
            \ bundle)
    elseif a:context.source__revision_locked
      call neobundle#installer#log(
            \ printf('[neobundle/install] (%'.len(max).'d/%d): %s',
            \ num, max, 'Locked'), 1)
    elseif a:context.source__output =~ 'up-to-date\|up to date'
      call neobundle#installer#log(
            \ printf('[neobundle/install] (%'.len(max).'d/%d): %s',
            \ num, max, 'Skipped'), 1)
    else
      call neobundle#installer#log(
            \ printf('[neobundle/install] (%'.len(max).'d/%d): %s',
            \ num, max, 'Updated'), 1)
      call add(a:context.source__synced_bundles,
            \ bundle)
    endif

    if !status && get(bundle, 'rev', '') != ''
          \ && !a:context.source__revision_locked
      " Lock revision.
      call s:sync(bundle, a:context, 1)
      return
    endif

    let a:context.source__process = {}
    let a:context.source__output = ''
    let a:context.source__number += 1
  endif
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
