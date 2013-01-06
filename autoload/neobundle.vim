"=============================================================================
" FILE: neobundle.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 04 Jan 2013.
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
" Version: 3.0, for Vim 7.2
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

" Check 'term' option value.
if !get(g:, 'loaded_neobundle', 0) && &term ==# 'builtin_gui'
  echoerr 'neobundle is initialized in .gvimrc!'
        \' neobundle must be initialized in .vimrc.'
endif

let g:loaded_neobundle = 1

if v:version < 702
  echoerr 'neobundle does not work this version of Vim (' . v:version . ').'
  finish
endif

" Global options definition." "{{{
call neobundle#util#set_default(
      \ 'g:neobundle#log_filename', '', 'g:neobundle_log_filename')
call neobundle#util#set_default(
      \ 'g:neobundle#default_site', 'github', 'g:neobundle_default_site')
call neobundle#util#set_default(
      \ 'g:neobundle#enable_tail_path', 1, 'g:neobundle_enable_tail_path')
call neobundle#util#set_default(
      \ 'g:neobundle#default_options', {})
"}}}

let s:neobundle_dir = get(
      \ filter(split(globpath(&runtimepath, 'bundle', 1), '\n'),
      \ 'isdirectory(v:val)'), 0, '~/.vim/bundle')

command! -nargs=+ NeoBundle
      \ call neobundle#config#bundle(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -bar NeoBundleCheck
      \ call neobundle#check()

command! -nargs=+ NeoBundleLazy
      \ call neobundle#config#lazy_bundle(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=+ NeoBundleFetch
      \ call neobundle#config#fetch_bundle(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=1 -complete=dir NeoBundleLocal
      \ call neobundle#local(<q-args>, {})

command! -nargs=+ NeoBundleDepends
      \ call neobundle#config#depends_bundle(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=+ NeoBundleDirectInstall
      \ call neobundle#config#direct_bundle(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=* -bar
      \ -complete=customlist,neobundle#complete_lazy_bundles
      \ NeoBundleSource
      \ call neobundle#config#source([<f-args>])

command! -nargs=+ -bar
      \ -complete=customlist,neobundle#complete_bundles
      \ NeoBundleDisable
      \ call neobundle#config#disable(<f-args>)

command! -nargs=? -bang -bar
      \ -complete=customlist,neobundle#complete_bundles
      \ NeoBundleInstall
      \ call neobundle#installer#install('!' == '<bang>', <q-args>)
command! -nargs=? -bang -bar
      \ -complete=customlist,neobundle#complete_bundles
      \ NeoBundleUpdate
      \ call neobundle#installer#install(('!' == '<bang>' ? 2 : 1), <q-args>)

command! -nargs=? -bang -bar
      \ -complete=customlist,neobundle#complete_deleted_bundles
      \ NeoBundleClean
      \ call neobundle#installer#clean('!' == '<bang>', <q-args>)

command! -nargs=+ -bang -bar
      \ -complete=customlist,neobundle#complete_bundles
      \ NeoBundleReinstall
      \ call neobundle#installer#reinstall(<q-args>)

command! -nargs=? -bang -bar
      \ NeoBundleList
      \ echo join(map(neobundle#config#get_neobundles(), 'v:val.name'), "\n")

command! -bar NeoBundleDocs
      \ call neobundle#installer#helptags(neobundle#config#get_neobundles())

command! -bar NeoBundleLog
      \ echo join(neobundle#installer#get_log(), "\n")

command! -bar NeoBundleUpdatesLog
      \ echo join(neobundle#installer#get_updates_log(), "\n")

let s:neobundle_runtime_dir = neobundle#util#substitute_path_separator(
      \ fnamemodify(expand('<sfile>'), ':p:h:h'))

function! neobundle#rc(...)
  if a:0 > 0
    let s:neobundle_dir = a:1
  endif

  let s:neobundle_dir =
        \ neobundle#util#substitute_path_separator(
        \ neobundle#util#expand(s:neobundle_dir))
  execute 'set runtimepath^='.fnameescape(
        \ neobundle#get_tags_dir())

  call neobundle#config#init()
endfunction

function! neobundle#get_neobundle_dir()
  return s:neobundle_dir
endfunction

function! neobundle#get_runtime_dir()
  return s:neobundle_runtime_dir
endfunction

function! neobundle#get_tags_dir()
  let dir = neobundle#get_neobundle_dir() . '/.neobundle/doc'
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  return dir
endfunction

function! neobundle#source(bundle_names)
  return neobundle#config#source(a:bundle_names)
endfunction

function! neobundle#complete_bundles(arglead, cmdline, cursorpos)
  return filter(map(neobundle#config#get_neobundles(), 'v:val.name'),
        \ 'stridx(tolower(v:val), tolower(a:arglead)) >= 0')
endfunction

function! neobundle#complete_lazy_bundles(arglead, cmdline, cursorpos)
  return filter(map(filter(neobundle#config#get_neobundles(),
        \ "!neobundle#config#is_sourced(v:val.name) && v:val.rtp != ''"), 'v:val.name'),
        \ 'stridx(tolower(v:val), tolower(a:arglead)) == 0')
endfunction

function! neobundle#complete_deleted_bundles(arglead, cmdline, cursorpos)
  let bundle_dirs = map(copy(neobundle#config#get_neobundles()), 'v:val.path')
  let all_dirs = split(neobundle#util#substitute_path_separator(
        \ globpath(neobundle#get_neobundle_dir(), '*')), "\n")
  let x_dirs = filter(all_dirs, 'index(bundle_dirs, v:val) < 0')

  return filter(map(x_dirs, "fnamemodify(v:val, ':t')"),
        \ 'stridx(v:val, a:arglead) == 0')
endfunction

function! neobundle#local(localdir, options)
  for dir in map(filter(split(glob(fnamemodify(
        \ neobundle#util#expand(a:localdir), ':p')
        \ . '*'), '\n'), "isdirectory(v:val)"),
        \ "neobundle#util#substitute_path_separator(
        \   substitute(fnamemodify(v:val, ':p'), '/$', '', ''))")
    call neobundle#config#bundle([dir,
          \ extend({ 'type' : 'nosync',
          \   'base' : neobundle#util#substitute_path_separator(
          \              fnamemodify(a:localdir, ':p')), }, a:options)])
  endfor
endfunction

function! neobundle#exists_not_installed_bundles()
  return !empty(neobundle#get_not_installed_bundles([]))
endfunction

function! neobundle#is_installed(...)
  let bundle_names = type(get(a:000, 0, [])) == type([]) ?
        \ get(a:000, 0, []) : [a:1]

  return !empty(s:get_installed_bundles(bundle_names))
endfunction

function! neobundle#is_sourced(name)
  return neobundle#config#is_sourced(a:name)
endfunction

function! neobundle#get_not_installed_bundle_names()
  return map(neobundle#get_not_installed_bundles([]), 'v:val.name')
endfunction

function! neobundle#get_not_installed_bundles(bundle_names)
  let bundles = empty(a:bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#fuzzy_search(a:bundle_names)

  return filter(copy(bundles),
        \ "!isdirectory(neobundle#util#expand(v:val.path))")
endfunction

function! neobundle#get(name)
  return neobundle#config#get(a:name)
endfunction

function! neobundle#config(name, dict)
  return neobundle#config#set(a:name, a:dict)
endfunction

function! neobundle#call_hook(hook_name, ...)
  let bundles = empty(a:000) ?
        \ neobundle#config#get_neobundles() : a:1
  for bundle in filter(copy(bundles),
        \ "has_key(v:val.hooks, a:hook_name) &&
        \  (a:hook_name !=# 'on_source' ||
        \       neobundle#config#is_sourced(v:val.name))")
    call call(bundle.hooks[a:hook_name], [bundle], bundle)
  endfor
endfunction

function! neobundle#check()
  if neobundle#exists_not_installed_bundles()
    echomsg 'Not installed bundles:'
          \ string(neobundle#get_not_installed_bundle_names())
    if confirm('Install bundles now?', "yes\nNo", 2) == 1
      call neobundle#installer#install(0, '')
    endif
    echo ''
  endif
endfunction

function! s:get_installed_bundles(bundle_names)
  let bundles = empty(a:bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(a:bundle_names)

  return filter(copy(bundles),
        \ "isdirectory(neobundle#util#expand(v:val.path))")
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
