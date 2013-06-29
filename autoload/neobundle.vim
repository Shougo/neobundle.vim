"=============================================================================
" FILE: neobundle.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 29 Jun 2013.
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
if exists('g:loaded_neobundle') && &term ==# 'builtin_gui'
  echoerr 'neobundle is initialized in .gvimrc!'
        \' neobundle must be initialized in .vimrc.'
endif

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
      \ 'g:neobundle#enable_name_conversion', 0)
call neobundle#util#set_default(
      \ 'g:neobundle#default_options', {})
"}}}

let s:neobundle_dir = get(
      \ filter(split(globpath(&runtimepath, 'bundle', 1), '\n'),
      \ 'isdirectory(v:val)'), 0, '~/.vim/bundle')

command! -nargs=+ NeoBundle
      \ call neobundle#parser#bundle(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -bar NeoBundleCheck
      \ call neobundle#check()

command! -nargs=+ NeoBundleLazy
      \ call neobundle#parser#lazy(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=+ NeoBundleFetch
      \ call neobundle#parser#fetch(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=1 -complete=dir NeoBundleLocal
      \ call neobundle#local(<q-args>, {})

command! -nargs=+ NeoBundleDepends
      \ call neobundle#parser#depends(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=+ NeoBundleDirectInstall
      \ call neobundle#parser#direct(
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
      \ call neobundle#installer#reinstall_names(<q-args>)

command! -nargs=? -bang -bar
      \ NeoBundleList
      \ echo join(map(neobundle#config#get_neobundles(), 'v:val.name'), "\n")

command! -bar NeoBundleDocs
      \ call neobundle#installer#helptags(neobundle#config#get_neobundles())

command! -bar NeoBundleLog
      \ echo join(neobundle#installer#get_log(), "\n")

command! -bar NeoBundleUpdatesLog
      \ echo join(neobundle#installer#get_updates_log(), "\n")

command! -bar NeoBundleDirectEdit
      \ execute 'edit' fnameescape(neobundle#get_neobundle_dir()).'/direct_bundles.vim'

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
        \ fnamemodify(neobundle#get_tags_dir(), ':h'))

  augroup neobundle
    autocmd!
  augroup END

  call neobundle#config#init()
  call neobundle#autoload#init()
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
        \ globpath(neobundle#get_neobundle_dir(), '*', 1)), "\n")
  let x_dirs = filter(all_dirs, 'index(bundle_dirs, v:val) < 0')

  return filter(map(x_dirs, "fnamemodify(v:val, ':t')"),
        \ 'stridx(v:val, a:arglead) == 0')
endfunction

function! neobundle#local(localdir, options)
  return neobundle#parser#local(a:localdir, a:options)
endfunction

function! neobundle#exists_not_installed_bundles()
  return !empty(neobundle#get_not_installed_bundles([]))
endfunction

function! neobundle#is_installed(...)
  return type(get(a:000, 0, [])) == type([]) ?
        \ !empty(neobundle#_get_installed_bundles(bundle_names)) :
        \ neobundle#config#is_installed(a:1)
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

  call neobundle#installer#_load_install_info(bundles)

  return filter(copy(bundles), "
        \  v:val.rtp != '' && !v:val.local
        \  && (!isdirectory(neobundle#util#expand(v:val.path))
        \ || (v:val.type !=# 'nosync' &&
        \     v:val.path ==# v:val.installed_path
        \     && v:val.uri !=# v:val.installed_uri))")
endfunction

function! neobundle#get(name)
  return neobundle#config#get(a:name)
endfunction
function! neobundle#get_hooks(name)
  return get(neobundle#config#get(a:name), 'hooks', {})
endfunction

function! neobundle#config(name, dict)
  return neobundle#config#set(a:name, a:dict)
endfunction

function! neobundle#call_hook(hook_name, ...)
  let bundles = neobundle#util#convert2list(
        \ (empty(a:000) ? neobundle#config#get_neobundles() : a:1))
  let bundles = filter(copy(bundles),
        \ 'has_key(v:val.hooks, a:hook_name) &&
        \  !has_key(v:val.called_hooks, a:hook_name)')

  if a:hook_name ==# 'on_source' || a:hook_name ==# 'on_post_source'
    let bundles = filter(neobundle#config#tsort(filter(bundles,
          \ 'neobundle#config#is_sourced(v:val.name) &&
          \  neobundle#config#is_installed(v:val.name)')),
          \ 'has_key(v:val.hooks, a:hook_name)
          \  && !has_key(v:val.called_hooks, a:hook_name)')
  endif

  for bundle in bundles
    call call(bundle.hooks[a:hook_name], [bundle], bundle)
    let bundle.called_hooks[a:hook_name] = 1
  endfor
endfunction

function! neobundle#check()
  if neobundle#installer#get_tags_info() !=#
        \ sort(map(neobundle#config#get_neobundles(), 'v:val.name'))
    " Recache automatically.
    NeoBundleDocs
  endif

  if !neobundle#exists_not_installed_bundles()
    return
  endif

  if has('gui_running') && has('vim_starting')
    " Note: :NeoBundleCheck cannot work in GUI startup.
    autocmd neobundle VimEnter * NeoBundleCheck
  else
    echomsg 'Not installed bundles: '
          \ string(neobundle#get_not_installed_bundle_names())
    if confirm('Install bundles now?', "yes\nNo", 2) == 1
      call neobundle#installer#install(0, '')
    endif
    echo ''
  endif
endfunction

function! neobundle#_get_installed_bundles(bundle_names)
  let bundles = empty(a:bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(a:bundle_names)

  return filter(copy(bundles),
        \ 'neobundle#config#is_installed(v:val.name)')
endfunction

function! neobundle#get_unite_sources()
  return neobundle#autoload#get_unite_sources()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
