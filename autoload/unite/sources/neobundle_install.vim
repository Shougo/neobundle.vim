"=============================================================================
" FILE: neobundle/install.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
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

function! unite#sources#neobundle_install#define() "{{{
  return [s:source_install, s:source_update]
endfunction"}}}

let s:source_install = {
      \ 'name' : 'neobundle/install',
      \ 'description' : 'install bundles',
      \ 'hooks' : {},
      \ 'default_kind' : 'word',
      \ 'syntax' : 'uniteSource__NeoBundleInstall',
      \ }

function! s:source_install.hooks.on_init(args, context) "{{{
  let bundle_names = filter(copy(a:args), "v:val != '!'")
  let a:context.source__bang =
        \ index(a:args, '!') >= 0 || !empty(bundle_names)
  let a:context.source__not_fuzzy = 0
  call s:init(a:context, bundle_names)
endfunction"}}}

function! s:source_install.hooks.on_syntax(args, context) "{{{
  syntax match uniteSource__NeoBundleInstall_Progress /(.\{-}):\s*.*/
        \ contained containedin=uniteSource__NeoBundleInstall
  highlight default link uniteSource__NeoBundleInstall_Progress String
  syntax match uniteSource__NeoBundleInstall_Source /|.\{-}|/
        \ contained containedin=uniteSource__NeoBundleInstall_Progress
  highlight default link uniteSource__NeoBundleInstall_Source Type
endfunction"}}}

function! s:source_install.hooks.on_close(args, context) "{{{
  if !empty(a:context.source__processes)
    for process in a:context.source__processes
      call process.proc.waitpid()
    endfor
  endif
endfunction"}}}

function! s:source_install.async_gather_candidates(args, context) "{{{
  let old_msgs = copy(neobundle#installer#get_log())

  if a:context.source__number < a:context.source__max_bundles
    while a:context.source__number < a:context.source__max_bundles
        \ && len(a:context.source__processes) <
        \      g:neobundle#install_max_processes
      call neobundle#installer#sync(
            \ a:context.source__bundles[a:context.source__number],
            \ a:context, 1)
    endwhile
  endif

  if !empty(a:context.source__processes)
    for process in a:context.source__processes
      call neobundle#installer#check_output(a:context, process, 1)
    endfor

    " Filter eof processes.
    call filter(a:context.source__processes, '!v:val.eof')
  else
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
    call neobundle#installer#update(
          \ a:context.source__synced_bundles)

    " Finish.
    call neobundle#installer#log('[neobundle/install] Completed.', 1)

    let a:context.is_async = 0
  endif

  return map(neobundle#installer#get_log()[len(old_msgs) :], "{
        \ 'word' : substitute(v:val, '^\\[.\\{-}\\]\\s*', '', ''),
        \ 'is_multiline' : 1,
        \}")
endfunction"}}}

function! s:source_install.complete(args, context, arglead, cmdline, cursorpos) "{{{
  return ['!'] +
        \ neobundle#commands#complete_bundles(a:arglead, a:cmdline, a:cursorpos)
endfunction"}}}

let s:source_update = deepcopy(s:source_install)
let s:source_update.name = 'neobundle/update'
let s:source_update.description = 'update bundles'

function! s:source_update.hooks.on_init(args, context) "{{{
  let a:context.source__bang =
        \ index(a:args, 'all') >= 0 ? 2 : 1
  let a:context.source__not_fuzzy = index(a:args, '!') >= 0
  let bundle_names = filter(copy(a:args),
        \ "v:val !=# 'all' && v:val !=# '!'")
  call s:init(a:context, bundle_names)
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
        \ a:context.source__not_fuzzy ?
        \ neobundle#config#search(a:bundle_names) :
        \ neobundle#config#fuzzy_search(a:bundle_names)

  call neobundle#installer#_load_install_info(
        \ a:context.source__bundles)

  let reinstall_bundles =
        \ neobundle#installer#get_reinstall_bundles(a:context.source__bundles)
  if !empty(reinstall_bundles)
    call neobundle#installer#reinstall(reinstall_bundles)
  endif

  let a:context.source__max_bundles =
        \ len(a:context.source__bundles)

  call neobundle#installer#clear_log()

  if empty(a:context.source__bundles)
    let a:context.is_async = 0
    call neobundle#installer#error(
          \ '[neobundle/install] Target bundles not found.' .
          \ ' You may use wrong bundle name.', 1)
  else
    call neobundle#installer#log(
          \ '[neobundle/install] Update started: ' .
          \     strftime('(%Y/%m/%d %H:%M:%S)'))
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
