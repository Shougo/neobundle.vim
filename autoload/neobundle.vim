"=============================================================================
" FILE: neobundle.vim
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
      \ 'g:neobundle#enable_name_conversion', 0)
call neobundle#util#set_default(
      \ 'g:neobundle#default_options', {})
call neobundle#util#set_default(
      \ 'g:neobundle#install_max_processes', 4,
      \ 'g:unite_source_neobundle_install_max_processes')
call neobundle#util#set_default(
      \ 'g:neobundle#install_process_timeout', 120)
"}}}

let g:neobundle#tapped = {}
let g:neobundle#hooks = {}
let s:neobundle_dir = ''
let s:neobundle_runtime_dir = neobundle#util#substitute_path_separator(
      \ fnamemodify(expand('<sfile>'), ':p:h:h'))

command! -nargs=+ NeoBundle
      \ call neobundle#parser#bundle(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -bar NeoBundleCheck
      \ call neobundle#commands#check()

command! -nargs=? -bar
      \ -complete=customlist,neobundle#commands#complete_bundles
      \ NeoBundleCheckUpdate
      \ call neobundle#commands#check_update(<q-args>)

command! -nargs=+ NeoBundleLazy
      \ call neobundle#parser#lazy(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=+ NeoBundleFetch
      \ call neobundle#parser#fetch(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=+ NeoBundleRecipe
      \ call neobundle#parser#recipe(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=1 -complete=dir NeoBundleLocal
      \ call neobundle#local(<q-args>, {})

command! -nargs=+ NeoBundleDirectInstall
      \ call neobundle#parser#direct(
      \   substitute(<q-args>, '\s"[^"]\+$', '', ''))

command! -nargs=* -bar
      \ -complete=customlist,neobundle#commands#complete_lazy_bundles
      \ NeoBundleSource
      \ call neobundle#config#source([<f-args>])

command! -nargs=+ -bar
      \ -complete=customlist,neobundle#commands#complete_bundles
      \ NeoBundleDisable
      \ call neobundle#config#disable(<f-args>)

command! -nargs=? -bang -bar
      \ -complete=customlist,neobundle#commands#complete_bundles
      \ NeoBundleInstall
      \ call neobundle#commands#install('!' == '<bang>', <q-args>)
command! -nargs=? -bang -bar
      \ -complete=customlist,neobundle#commands#complete_bundles
      \ NeoBundleUpdate
      \ call neobundle#commands#install(('!' == '<bang>' ? 2 : 1), <q-args>)

command! -nargs=* -bang -bar
      \ -complete=customlist,neobundle#commands#complete_deleted_bundles
      \ NeoBundleClean
      \ call neobundle#commands#clean('!' == '<bang>', <f-args>)

command! -nargs=+ -bang -bar
      \ -complete=customlist,neobundle#commands#complete_bundles
      \ NeoBundleReinstall
      \ call neobundle#commands#reinstall(<q-args>)

command! -nargs=? -bar
      \ -complete=customlist,neobundle#commands#complete_bundles
      \ NeoBundleGC
      \ call neobundle#commands#gc(<q-args>)

command! -nargs=? -bang -bar
      \ NeoBundleList
      \ call neobundle#commands#list()

command! -bar NeoBundleDocs
      \ call neobundle#commands#helptags(neobundle#config#get_neobundles())

command! -bar NeoBundleLog
      \ echo join(neobundle#installer#get_log(), "\n")

command! -bar NeoBundleUpdatesLog
      \ echo join(neobundle#installer#get_updates_log(), "\n")

command! -bar NeoBundleExtraEdit
      \ execute 'edit' fnameescape(neobundle#get_neobundle_dir()).'/extra_bundles.vim'

command! -bar NeoBundleCount
      \ echo len(neobundle#config#get_neobundles())

command! -bar NeoBundleSaveCache
      \ call neobundle#commands#save_cache()
command! -bar NeoBundleLoadCache
      \ call neobundle#commands#load_cache()
command! -bar NeoBundleClearCache
      \ call neobundle#commands#clear_cache()

command! -nargs=1 -bar
      \ -complete=customlist,neobundle#commands#complete_bundles
      \ NeoBundleRollback
      \ call neobundle#commands#rollback(<f-args>)

function! neobundle#rc(...) "{{{
  let path = (a:0 > 0) ? a:1 :
        \ get(filter(split(globpath(&runtimepath, 'bundle', 1), '\n'),
        \ 'isdirectory(v:val)'), 0, '~/.vim/bundle')
  return neobundle#init#_rc(path, 0)
endfunction"}}}
function! neobundle#begin(...) "{{{
  let path = (a:0 > 0) ? a:1 :
        \ get(filter(split(globpath(&runtimepath, 'bundle', 1), '\n'),
        \ 'isdirectory(v:val)'), 0, '~/.vim/bundle')
  return neobundle#init#_rc(path, 1)
endfunction"}}}
function! neobundle#end() "{{{
  call neobundle#config#final()
endfunction"}}}

function! neobundle#set_neobundle_dir(path)
  let s:neobundle_dir = a:path
endfunction

function! neobundle#get_neobundle_dir()
  return s:neobundle_dir
endfunction

function! neobundle#get_runtime_dir()
  return s:neobundle_runtime_dir
endfunction

function! neobundle#get_tags_dir() "{{{
  let dir = neobundle#get_neobundle_dir() . '/.neobundle/doc'
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif
  return dir
endfunction"}}}

function! neobundle#get_rtp_dir()
  return s:neobundle_dir . '/.neobundle'
endfunction

function! neobundle#source(bundle_names)
  return neobundle#config#source(a:bundle_names)
endfunction

function! neobundle#local(localdir, ...)
  return neobundle#parser#local(
        \ a:localdir, get(a:000, 0, {}), get(a:000, 1, []))
endfunction

function! neobundle#exists_not_installed_bundles()
  return !empty(neobundle#get_not_installed_bundles([]))
endfunction

function! neobundle#is_installed(...) "{{{
  return type(get(a:000, 0, [])) == type([]) ?
        \ !empty(neobundle#_get_installed_bundles(get(a:000, 0, []))) :
        \ neobundle#config#is_installed(a:1)
endfunction"}}}

function! neobundle#is_sourced(name)
  return neobundle#config#is_sourced(a:name)
endfunction

function! neobundle#has_cache()
  return filereadable(neobundle#commands#get_cache_file())
endfunction

function! neobundle#has_fresh_cache(...)
  " Check if the cache file is newer than the vimrc file.
  let vimrc = get(a:000, 0, $MYVIMRC)
  let cache = neobundle#commands#get_cache_file()
  return filereadable(cache)
        \ && (!filereadable(vimrc)
        \    || getftime(cache) >= getftime(vimrc))
endfunction

function! neobundle#get_not_installed_bundle_names()
  return map(neobundle#get_not_installed_bundles([]), 'v:val.name')
endfunction

function! neobundle#get_not_installed_bundles(bundle_names) "{{{
  let bundles = empty(a:bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#fuzzy_search(a:bundle_names)

  call neobundle#installer#_load_install_info(bundles)

  return filter(copy(bundles), "
        \  v:val.rtp != '' && !v:val.local
        \  && !isdirectory(neobundle#util#expand(v:val.path))
        \")
endfunction"}}}

function! neobundle#get(name)
  return neobundle#config#get(a:name)
endfunction
function! neobundle#get_hooks(name)
  return get(neobundle#config#get(a:name), 'hooks', {})
endfunction

function! neobundle#tap(name) "{{{
  let g:neobundle#tapped = neobundle#get(a:name)
  let g:neobundle#hooks = get(neobundle#get(a:name), 'hooks', {})
  return !empty(g:neobundle#tapped)
endfunction"}}}
function! neobundle#untap() "{{{
  let g:neobundle#tapped = {}
  let g:neobundle#hooks = {}
endfunction"}}}

function! neobundle#bundle(arg, ...) "{{{
  let opts = get(a:000, 0, {})
  call map(neobundle#util#convert2list(a:arg),
        \ "neobundle#config#add(neobundle#parser#_init_bundle(
        \     v:val, [deepcopy(opts)]))")
endfunction"}}}

function! neobundle#config(arg, ...) "{{{
  " Use neobundle#tapped or name.
  return type(a:arg) == type({}) ?
        \   neobundle#config#set(g:neobundle#tapped.name, a:arg) :
        \ type(a:arg) == type('') ?
        \   neobundle#config#set(a:arg, a:1) :
        \   map(copy(a:arg), "neobundle#config#set(v:val, deepcopy(a:1))")
endfunction"}}}

function! neobundle#call_hook(hook_name, ...) "{{{
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
    if type(bundle.hooks[a:hook_name]) == type('')
      execute 'source' fnameescape(bundle.hooks[a:hook_name])
    else
      call call(bundle.hooks[a:hook_name], [bundle], bundle)
    endif
    let bundle.called_hooks[a:hook_name] = 1
  endfor
endfunction"}}}

function! neobundle#_get_installed_bundles(bundle_names) "{{{
  let bundles = empty(a:bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(a:bundle_names)

  return filter(copy(bundles),
        \ 'neobundle#config#is_installed(v:val.name)')
endfunction"}}}

function! neobundle#get_unite_sources()
  return neobundle#autoload#get_unite_sources()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
