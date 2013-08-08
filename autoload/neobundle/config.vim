"=============================================================================
" FILE: config.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 08 Aug 2013.
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

if !exists('s:neobundles')
  let s:neobundles = {}
  let s:sourced_neobundles = {}
endif

function! neobundle#config#init() "{{{
  filetype off

  for bundle in values(s:neobundles)
    if (!bundle.resettable && !bundle.lazy) ||
          \ (bundle.sourced && bundle.lazy
          \ && neobundle#is_sourced(bundle.name))
      call neobundle#config#rtp_add(bundle)
    elseif bundle.resettable
      " Reset.
      call neobundle#config#rtp_rm(bundle)

      call remove(s:neobundles, bundle.name)
    endif
  endfor

  " Load direct installed bundles.
  call neobundle#config#load_direct_bundles()

  augroup neobundle
    autocmd VimEnter * call s:on_vim_enter()
  augroup END
endfunction"}}}

function! neobundle#config#get(name) "{{{
  return get(s:neobundles, a:name, {})
endfunction"}}}

function! neobundle#config#get_neobundles() "{{{
  return values(s:neobundles)
endfunction"}}}

function! neobundle#config#get_autoload_bundles() "{{{
  return filter(values(s:neobundles),
        \ "!v:val.sourced && v:val.rtp != '' && v:val.lazy")
endfunction"}}}

function! neobundle#config#source_bundles(bundles) "{{{
  if !empty(a:bundles)
    call neobundle#config#source(map(copy(a:bundles),
          \ "type(v:val) == type({}) ? v:val.name : v:val"))
  endif
endfunction"}}}

function! neobundle#config#check_not_exists(names, ...) "{{{
  " For infinite loop.
  let self = get(a:000, 0, [])

  let _ = map(neobundle#get_not_installed_bundles(a:names), 'v:val.name')
  for bundle in map(filter(copy(a:names),
        \ 'index(self, v:val) < 0 && has_key(s:neobundles, v:val)'),
        \ 's:neobundles[v:val]')
    call add(self, bundle.name)

    if !empty(bundle.depends)
      let _ += neobundle#config#check_not_exists(
            \ map(copy(bundle.depends), 'v:val.name'), self)
    endif
  endfor

  return neobundle#util#uniq(_)
endfunction"}}}

function! neobundle#config#source(names, ...) "{{{
  let is_force = get(a:000, 0, 1)

  let names = neobundle#util#convert2list(a:names)
  let bundles = empty(names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(names)
  let not_exists = neobundle#config#check_not_exists(names)
  if !empty(not_exists)
    call neobundle#util#print_error(
          \ 'Not installed plugin-names are detected : '. string(not_exists))
  endif

  let rtps = neobundle#util#split_rtp()
  let bundles = filter(bundles,
        \ "!neobundle#config#is_sourced(v:val.name) ||
        \ (v:val.rtp != '' && index(rtps, v:val.rtp) < 0)")
  if empty(bundles)
    return
  endif

  let filetype_out = ''
  redir => filetype_out
  silent filetype
  redir END

  redir => filetype_before
  execute 'silent autocmd FileType' &filetype
  redir END

  let reset_ftplugin = 0
  for bundle in bundles
    let bundle.sourced = 1
    let bundle.disabled = 0

    if !get(s:sourced_neobundles, bundle.name, 0)
      " Unmap dummy mappings.
      for [mode, mapping] in get(bundle, 'dummy_mappings', [])
        silent! execute mode.'unmap' mapping
      endfor

      " Delete dummy commands.
      for command in get(bundle, 'dummy_commands', [])
        silent! execute 'delcommand' command
      endfor

      let s:sourced_neobundles[bundle.name] = 1
    endif

    let bundle.dummy_mappings = []
    let bundle.dummy_commands = []

    call neobundle#config#rtp_add(bundle)

    if exists('g:loaded_neobundle') || is_force
      call neobundle#call_hook('on_source', bundle)

      " Reload script files.
      for directory in ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin']
        for file in split(glob(bundle.rtp.'/'.directory.'/**/*.vim'), '\n')
          silent! source `=file`
        endfor
      endfor

      if exists('#'.bundle.augroup.'#VimEnter')
        execute 'silent doautocmd' bundle.augroup 'VimEnter'

        if has('gui_running') && &term ==# 'builtin_gui'
          execute 'silent doautocmd' bundle.augroup 'GUIEnter'
        endif
      endif
    endif

    if !reset_ftplugin
      for filetype in split(&filetype, '\.')
        let base = bundle.rtp . '/' . directory
        for directory in ['ftplugin', 'indent', 'syntax',
              \ 'after/ftplugin', 'after/indent', 'after/syntax']
          if filereadable(base.'/'.filetype.'.vim') ||
                \ (directory =~# 'ftplugin$' &&
                \   isdirectory(base . '/' . filetype) ||
                \   glob(base.'/'.filetype.'_*.vim') != '')
            let reset_ftplugin = 1
            break
          endif
        endfor
      endfor
    endif
  endfor

  redir => filetype_after
  execute 'silent autocmd FileType' &filetype
  redir END

  if reset_ftplugin
    filetype off

    if filetype_out =~# 'detection:ON'
      silent! filetype on
    endif

    if filetype_out =~# 'plugin:ON'
      silent! filetype plugin on
    endif

    if filetype_out =~# 'indent:ON'
      silent! filetype indent on
    endif

    " Reload filetype plugins.
    let &l:filetype = &l:filetype
  elseif filetype_before !=# filetype_after
    execute 'doautocmd FileType' &filetype
  endif

  if exists('g:loaded_neobundle')
    call neobundle#call_hook('on_post_source', bundles)
  endif
endfunction"}}}

function! neobundle#config#disable(arg) "{{{
  let bundle_names = neobundle#config#search(split(a:arg))
  if empty(bundle_names)
    return
  endif

  for bundle in bundle_names
    call neobundle#config#rtp_rm(bundle)
    let bundle.sourced = 0
    let bundle.disabled = 1
  endfor
endfunction"}}}

function! neobundle#config#is_sourced(name) "{{{
  return get(neobundle#config#get(a:name), 'sourced', 0)
endfunction"}}}

function! neobundle#config#is_installed(name) "{{{
  return isdirectory(get(neobundle#config#get(a:name), 'path', ''))
endfunction"}}}

function! neobundle#config#rm(path) "{{{
  for bundle in filter(neobundle#config#get_neobundles(),
        \ 'v:val.path ==# a:path')
    call neobundle#config#rtp_rm(bundle)
    call remove(s:neobundles, bundle.name)
  endfor
endfunction"}}}

function! neobundle#config#get_types(...) "{{{
  if !exists('s:neobundle_types')
    " Load neobundle types.
    let s:neobundle_types = []
    for define in map(split(globpath(&runtimepath,
          \ 'autoload/neobundle/types/*.vim', 1), '\n'),
          \ "neobundle#types#{fnamemodify(v:val, ':t:r')}#define()")
      for dict in neobundle#util#convert2list(define)
        if !empty(dict)
          call add(s:neobundle_types, dict)
        endif
      endfor
      unlet define
    endfor

    let s:neobundle_types = neobundle#util#uniq(
          \ s:neobundle_types, 'v:val.name')
  endif

  let type = get(a:000, 0, '')

  return (type == '') ? s:neobundle_types :
        \ get(filter(copy(s:neobundle_types), 'v:val.name ==# type'), 0, {})
endfunction"}}}

function! neobundle#config#rtp_rm_all_bundles() "{{{
  call filter(values(s:neobundles), 'neobundle#config#rtp_rm(v:val)')
endfunction"}}}

function! neobundle#config#rtp_rm(bundle) "{{{
  execute 'set rtp-='.fnameescape(a:bundle.rtp)
  if isdirectory(a:bundle.rtp.'/after')
    execute 'set rtp-='.fnameescape(a:bundle.rtp.'/after')
  endif
endfunction"}}}

function! neobundle#config#rtp_add(bundle) abort "{{{
  if has_key(s:neobundles, a:bundle.name)
    call neobundle#config#rtp_rm(s:neobundles[a:bundle.name])
  endif

  let rtp = a:bundle.rtp
  if isdirectory(rtp)
    " Join to the tail in runtimepath.
    let rtps = neobundle#util#split_rtp(&runtimepath)
    let n = index(rtps, neobundle#get_rtp_dir())
    let &runtimepath = neobundle#util#join_rtp(
          \ insert(rtps, rtp, n), &runtimepath, rtp)
  endif
  if isdirectory(rtp.'/after')
    execute 'set rtp+='.fnameescape(rtp.'/after')
  endif
endfunction"}}}

function! neobundle#config#search(bundle_names, ...) "{{{
  " For infinite loop.
  let self = get(a:000, 0, [])

  let _ = []
  for bundle in copy(filter(neobundle#config#get_neobundles(),
        \ 'index(self, v:val.name) < 0 &&
        \       index(a:bundle_names, v:val.name) >= 0'))
    call add(self, bundle.name)

    let _ += neobundle#config#search(
          \ map(copy(bundle.depends), 'v:val.name'), self)
    call add(_, bundle)
  endfor

  return neobundle#util#uniq(_)
endfunction"}}}

function! neobundle#config#search_simple(bundle_names) "{{{
  return filter(neobundle#config#get_neobundles(),
        \ 'index(a:bundle_names, v:val.name) >= 0')
endfunction"}}}

function! neobundle#config#fuzzy_search(bundle_names) "{{{
  let bundles = []
  for name in a:bundle_names
    let bundles += filter(neobundle#config#get_neobundles(),
          \ 'stridx(v:val.name, name) >= 0')
  endfor

  let _ = []
  for bundle in bundles
    let _ += neobundle#config#search(
          \ map(copy(bundle.depends), 'v:val.name'))
    call add(_, bundle)
  endfor

  return neobundle#util#uniq(_)
endfunction"}}}

function! neobundle#config#load_direct_bundles() "{{{
  let path = neobundle#get_neobundle_dir() . '/direct_bundles.vim'

  if filereadable(path)
    source `=path`
  endif
endfunction"}}}

function! neobundle#config#save_direct(arg) "{{{
  let path = neobundle#get_neobundle_dir() . '/direct_bundles.vim'
  let bundles = filereadable(path) ? readfile(path) : []
  call writefile(add(bundles, 'NeoBundle ' . a:arg), path)
endfunction"}}}

function! neobundle#config#set(name, dict) "{{{
  let bundle = neobundle#config#get(a:name)
  if empty(bundle)
    return
  endif

  let bundle = neobundle#init#_bundle(extend(bundle, a:dict))
  if bundle.lazy && bundle.sourced &&
        \ !get(s:sourced_neobundles, bundle.name, 0)
    " Remove from runtimepath.
    call neobundle#config#rtp_rm(bundle)
    let bundle.sourced = 0
  endif

  call neobundle#config#add(bundle, 1)
endfunction"}}}

function! neobundle#config#add(bundle, ...) "{{{
  let bundle = a:bundle
  let is_force = get(a:000, 0, bundle.local)

  if bundle.disabled
        \ || (!is_force && !bundle.overwrite &&
        \     has_key(s:neobundles, bundle.name))
    return
  endif

  let prev_bundle = get(s:neobundles, bundle.name, {})

  if get(prev_bundle, 'local', 0) && !bundle.local
    return
  endif

  if !empty(prev_bundle)
    call neobundle#config#rtp_rm(prev_bundle)
  endif
  let s:neobundles[bundle.name] = bundle

  if (bundle.gui && !has('gui_running'))
        \ || (bundle.terminal && has('gui_running'))
        \ || (bundle.vim_version != ''
        \     && s:check_version(bundle.vim_version))
        \ || (!empty(bundle.external_commands)
        \     && s:check_external_commands(bundle))
    " Ignore load.
    return
  endif

  " Add depends.
  for depend in a:bundle.depends
    if !has_key(s:neobundles, depend.name)
      call neobundle#config#add(depend)
    elseif !depend.lazy
      " Load automatically.
      call neobundle#config#source(depend.name)
    endif
  endfor

  if !bundle.lazy && bundle.rtp != ''
    if !has('vim_starting')
      " Load automatically.
      call neobundle#config#source(bundle.name)
    else
      let bundle.sourced = 1
      call neobundle#config#rtp_add(bundle)
    endif
  elseif bundle.lazy
    if neobundle#config#is_sourced(bundle.name)
      " Already sourced.
      call neobundle#config#rtp_add(bundle)
    else
      let bundle.dummy_commands = []
      for item in neobundle#util#convert2list(
            \ get(bundle.autoload, 'commands', []))
        let command = type(item) == type('') ?
              \ { 'name' : item } : item

        " Define dummy commands.
        silent! execute 'command ' . (get(command, 'complete', '') != '' ?
              \ ('-complete=' . command.complete) : '')
              \ . ' -bang -range -nargs=*' command.name printf(
              \ "call neobundle#autoload#command(%s, %s, <q-args>,
              \  expand('<bang>'), expand('<line1>'), expand('<line2>'))",
              \   string(command.name), string(bundle.name))
        unlet item

        call add(bundle.dummy_commands, command.name)
      endfor

      let bundle.dummy_mappings = []
      for item in neobundle#util#convert2list(
            \ get(bundle.autoload, 'mappings', []))
        if type(item) == type([])
          let [modes, mappings] = [item[0], item[1:]]
        else
          let [modes, mappings] = ['nxo', [item]]
        endif

        for mapping in mappings
          " Define dummy mappings.
          for mode in filter(split(modes, '\zs'),
                \ "index(['n', 'v', 'x', 'o', 'i'], v:val) >= 0")
            silent! execute mode.'noremap <unique><silent>' mapping printf(
                  \ (mode ==# 'i' ? "\<C-o>:" : ":\<C-u>").
                  \   "call neobundle#autoload#mapping(%s, %s, %s)<CR>",
                  \   string(mapping), string(bundle.name), string(mode))

            call add(bundle.dummy_mappings, [mode, mapping])
          endfor
        endfor

        unlet item
      endfor
    endif
  endif

  if !is_force && bundle.overwrite &&
        \ !empty(prev_bundle) && prev_bundle.overwrite &&
        \ bundle.orig_arg !=# prev_bundle.orig_arg &&
        \ prev_bundle.resettable && prev_bundle.overwrite
    " echomsg string(bundle.orig_arg)
    " echomsg string(prev_bundle.orig_arg)
    " Warning.
    call neobundle#util#print_error(
          \ 'Overwrite previous neobundle configuration in ' . bundle.name)
  endif
endfunction"}}}

function! neobundle#config#tsort(bundles) "{{{
  let sorted = []
  let mark = {}
  for target in a:bundles
    call s:tsort_impl(target, a:bundles, mark, sorted)
  endfor

  return sorted
endfunction"}}}

function! s:tsort_impl(target, bundles, mark, sorted) "{{{
  if has_key(a:mark, a:target.name)
    return
  endif

  let a:mark[a:target.name] = 1
  for depend in get(a:target, 'depends', [])
    call s:tsort_impl(get(s:neobundles, depend.name, depend),
          \ a:bundles, a:mark, a:sorted)
  endfor

  call add(a:sorted, a:target)
endfunction"}}}

function! s:on_vim_enter() "{{{
  " Call hooks.
  call neobundle#call_hook('on_source')
  call neobundle#call_hook('on_post_source')
endfunction"}}}

function! s:check_version(min_version) "{{{
  let versions = split(a:min_version, '\.')
  let major = get(versions, 0, 0)
  let minor = get(versions, 1, 0)
  let patch = get(versions, 2, 0)
  let min_version = major * 100 + minor
  return v:version < min_version ||
        \ (patch != 0 && v:version == min_version && !has('patch'.patch))
endfunction"}}}

function! s:check_external_commands(bundle) "{{{
  " Environment check.
  let external_commands = a:bundle.external_commands
  if type(external_commands) == type([])
        \ || type(external_commands) == type('')
    let commands = external_commands
  elseif neobundle#util#is_windows() && has_key(external_commands, 'windows')
    let commands = external_commands.windows
  elseif neobundle#util#is_mac() && has_key(external_commands, 'mac')
    let commands = external_commands.mac
  elseif neobundle#util#is_cygwin() && has_key(external_commands, 'cygwin')
    let commands = external_commands.cygwin
  elseif !neobundle#util#is_windows() && has_key(external_commands, 'unix')
    let commands = external_commands.unix
  elseif has_key(external_commands, 'others')
    let commands = external_commands.others
  else
    " Invalid.
    return 0
  endif

  for command in neobundle#util#convert2list(commands)
    if !executable(command)
      return 1
    endif
  endfor
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
