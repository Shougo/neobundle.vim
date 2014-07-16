"=============================================================================
" FILE: config.vim
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

if !exists('s:neobundles')
  let s:is_block = 0
  let s:neobundles = {}
  let s:sourced_neobundles = {}
  let neobundle#tapped = {}
  let s:lazy_rtps = []
endif

function! neobundle#config#init(is_block) "{{{
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

  " Load extra bundles configuration.
  call neobundle#config#load_extra_bundles()

  augroup neobundle
    autocmd VimEnter * call s:on_vim_enter()
  augroup END

  let s:is_block = a:is_block
  let s:lazy_rtps = []
endfunction"}}}
function! neobundle#config#final() "{{{
  " Join to the tail in runtimepath.
  let rtps = neobundle#util#split_rtp(&runtimepath)
  let index = index(rtps, neobundle#get_rtp_dir())
  for rtp in filter(s:lazy_rtps, 'isdirectory(v:val)')
    call insert(rtps, rtp, index)
    let index += 1

    if isdirectory(rtp.'/after')
      call add(rtps, fnameescape(rtp.'/after'))
    endif
  endfor
  let &runtimepath = neobundle#util#join_rtp(rtps, &runtimepath, '')

  let s:is_block = 0
endfunction"}}}

function! neobundle#config#get(name) "{{{
  return get(s:neobundles, a:name, {})
endfunction"}}}

function! neobundle#config#get_neobundles() "{{{
  return values(s:neobundles)
endfunction"}}}

function! neobundle#config#get_autoload_bundles() "{{{
  return filter(values(s:neobundles),
        \ "!v:val.sourced && v:val.lazy")
endfunction"}}}

function! neobundle#config#source_bundles(bundles) "{{{
  if !empty(a:bundles)
    call neobundle#config#source(map(copy(a:bundles),
          \ "type(v:val) == type({}) ? v:val.name : v:val"))
  endif
endfunction"}}}

function! neobundle#config#check_not_exists(names, ...) "{{{
  " For infinite loop.
  let l:self = get(a:000, 0, [])

  let _ = map(neobundle#get_not_installed_bundles(a:names), 'v:val.name')
  for bundle in map(filter(copy(a:names),
        \ 'index(self, v:val) < 0 && has_key(s:neobundles, v:val)'),
        \ 's:neobundles[v:val]')
    call add(l:self, bundle.name)

    if !empty(bundle.depends)
      let _ += neobundle#config#check_not_exists(
            \ map(copy(bundle.depends), 'v:val.name'), self)
    endif
  endfor

  if len(_) > 1
    let _ = neobundle#util#uniq(_)
  endif

  return _
endfunction"}}}

function! neobundle#config#source(names, ...) "{{{
  let is_force = get(a:000, 0, 1)

  let names = neobundle#util#convert2list(a:names)
  let bundles = empty(names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(names)

  let rtps = neobundle#util#split_rtp(&runtimepath)
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
  silent autocmd FileType
  redir END

  let reset_ftplugin = 0
  for bundle in bundles
    let bundle.sourced = 1
    let bundle.disabled = 0

    let s:sourced_neobundles[bundle.name] = 1

    if !empty(bundle.dummy_mappings)
      for [mode, mapping] in bundle.dummy_mappings
        silent! execute mode.'unmap' mapping
      endfor
      let bundle.dummy_mappings = []
    endif

    call neobundle#config#rtp_add(bundle)

    if exists('g:loaded_neobundle') || is_force
      call s:on_source(bundle)
    endif

    call neobundle#autoload#source(bundle.name)

    if !reset_ftplugin
      let reset_ftplugin = s:is_reset_ftplugin(&filetype, bundle.rtp)
    endif
  endfor

  redir => filetype_after
  silent autocmd FileType
  redir END

  if reset_ftplugin
    call s:reset_ftplugin(filetype_out)
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
  let type = get(a:000, 0, '')

  if type ==# 'git'
    if !exists('s:neobundle_type_git')
      let s:neobundle_type_git = neobundle#types#git#define()
    endif

    return s:neobundle_type_git
  endif

  if !exists('s:neobundle_types')
    " Load neobundle types.
    let s:neobundle_types = []
    for list in map(split(globpath(&runtimepath,
          \ 'autoload/neobundle/types/*.vim', 1), '\n'),
          \ "neobundle#util#convert2list(
          \    neobundle#types#{fnamemodify(v:val, ':t:r')}#define())")
      let s:neobundle_types += list
    endfor

    let s:neobundle_types = neobundle#util#uniq(
          \ s:neobundle_types, 'v:val.name')
  endif

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

  if s:is_block
    " Add rtp lazily.
    call add(s:lazy_rtps, a:bundle.rtp)
    return
  endif

  let rtp = a:bundle.rtp
  if isdirectory(rtp)
    " Join to the tail in runtimepath.
    let rtps = neobundle#util#split_rtp(&runtimepath)
    let &runtimepath = neobundle#util#join_rtp(
          \ insert(rtps, rtp, index(rtps, neobundle#get_rtp_dir())),
          \ &runtimepath, rtp)
  endif
  if isdirectory(rtp.'/after')
    execute 'set rtp+='.fnameescape(rtp.'/after')
  endif
endfunction"}}}

function! neobundle#config#search(bundle_names, ...) "{{{
  if empty(a:bundle_names)
    return []
  endif

  " For infinite loop.
  let l:self = get(a:000, 0, [])

  let _ = []
  let bundles = len(a:bundle_names) != 1 ?
        \ filter(neobundle#config#get_neobundles(),
        \ 'index(a:bundle_names, v:val.name) >= 0 &&
        \  (empty(self) || index(self, v:val.name) < 0)') :
        \ has_key(s:neobundles, a:bundle_names[0]) ?
        \     [s:neobundles[a:bundle_names[0]]] : []
  for bundle in bundles
    call add(l:self, bundle.name)

    if !empty(bundle.depends)
      let _ += neobundle#config#search(
            \ map(copy(bundle.depends), 'v:val.name'), self)
    endif
    call add(_, bundle)
  endfor

  if len(_) > 1
    let _ = neobundle#util#uniq(_)
  endif

  return _
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
    if !empty(bundle.depends)
      let _ += neobundle#config#search(
            \ map(copy(bundle.depends), 'v:val.name'))
    endif
    call add(_, bundle)
  endfor

  if len(_) > 1
    let _ = neobundle#util#uniq(_)
  endif

  return _
endfunction"}}}

function! neobundle#config#load_extra_bundles() "{{{
  let path = neobundle#get_neobundle_dir() . '/extra_bundles.vim'

  if filereadable(path)
    source `=path`
  endif
endfunction"}}}

function! neobundle#config#save_direct(arg) "{{{
  if neobundle#util#is_sudo()
    call neobundle#util#print_error(
          \ '"sudo vim" is detected. This feature is disabled.')
    return
  endif

  let path = neobundle#get_neobundle_dir() . '/extra_bundles.vim'
  let bundles = filereadable(path) ? readfile(path) : []
  call writefile(add(bundles, 'NeoBundle ' . a:arg), path)
endfunction"}}}

function! neobundle#config#set(name, dict) "{{{
  let bundle = neobundle#config#get(a:name)
  if empty(bundle)
    call neobundle#util#print_error(
          \ '[neobundle] Plugin name "' . a:name . '" is not defined.')
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
  if empty(a:bundle)
    return
  endif

  let bundle = a:bundle
  let is_force = get(a:000, 0, bundle.local)

  if !is_force && !bundle.overwrite &&
        \     has_key(s:neobundles, bundle.name)
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

  if bundle.disabled
        \ || (bundle.gui && !has('gui_running'))
        \ || (bundle.terminal && has('gui_running'))
        \ || (bundle.vim_version != ''
        \     && s:check_version(bundle.vim_version))
        \ || (!empty(bundle.external_commands)
        \     && neobundle#config#check_commands(bundle.external_commands))
    " Ignore load.
    return
  endif

  if !empty(bundle.depends)
    call s:add_depends(bundle)
  endif

  if !bundle.lazy && bundle.rtp != ''
    if !has('vim_starting')
      " Load automatically.
      call neobundle#config#source(bundle.name, bundle.force)
    else
      let bundle.sourced = 1
      call neobundle#config#rtp_add(bundle)

      if bundle.force
        runtime! plugin/**/*.vim
      endif
    endif
  elseif bundle.lazy
    call s:add_lazy(bundle)
  endif

  if !is_force && bundle.overwrite &&
        \ !empty(prev_bundle) && prev_bundle.overwrite &&
        \ bundle.orig_arg !=# prev_bundle.orig_arg &&
        \ prev_bundle.resettable && prev_bundle.overwrite
    " echomsg string(bundle.orig_arg)
    " echomsg string(prev_bundle.orig_arg)
    " Warning.
    call neobundle#util#print_error(
          \ '[neobundle] Plugin "' . bundle.name .
          \ '" appears to be defined multiple times in .vimrc.')
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

function! neobundle#config#get_lazy_rtps() "{{{
  return s:lazy_rtps
endfunction"}}}

function! neobundle#config#check_commands(commands) "{{{
  " Environment check.
  if type(a:commands) == type([])
        \ || type(a:commands) == type('')
    let commands = a:commands
  elseif neobundle#util#is_windows() && has_key(a:commands, 'windows')
    let commands = a:commands.windows
  elseif neobundle#util#is_mac() && has_key(a:commands, 'mac')
    let commands = a:commands.mac
  elseif neobundle#util#is_cygwin() && has_key(a:commands, 'cygwin')
    let commands = a:commands.cygwin
  elseif !neobundle#util#is_windows() && has_key(a:commands, 'unix')
    let commands = a:commands.unix
  elseif has_key(a:commands, 'others')
    let commands = a:commands.others
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

function! s:add_depends(bundle) "{{{
  " Add depends.
  for depend in a:bundle.depends
    if !has_key(s:neobundles, depend.name)
      call neobundle#config#add(depend)
    elseif !depend.lazy
      " Load automatically.
      call neobundle#config#source(depend.name, depend.force)
    endif
  endfor
endfunction"}}}

function! s:add_lazy(bundle) "{{{
  let bundle = a:bundle

  " Auto set autoload keys.
  for key in filter([
        \ 'filetypes', 'filename_patterns',
        \ 'commands', 'functions', 'mappings', 'unite_sources',
        \ 'insert', 'explorer', 'on_source', 'function_prefix',
        \ ], 'has_key(bundle, v:val)')
    let bundle.autoload[key] = bundle[key]
    call remove(bundle, key)
  endfor

  if !has_key(bundle.autoload, 'function_prefix')
    let bundle.autoload.function_prefix =
          \ neobundle#parser#_function_prefix(bundle.name)
  endif
  if !has_key(bundle.autoload, 'unite_sources')
        \ && bundle.name =~ '^unite-'
    let bundle.autoload.unite_sources =
          \ matchstr(bundle.name, '^unite-\zs.*')
  endif

  if neobundle#config#is_sourced(bundle.name)
    " Already sourced.
    call neobundle#config#rtp_add(bundle)
  else
    if has_key(bundle.autoload, 'commands')
      call s:add_dummy_commands(bundle)
    endif

    if has_key(bundle.autoload, 'mappings')
      call s:add_dummy_mappings(bundle)
    endif
  endif
endfunction"}}}

function! s:add_dummy_commands(bundle) "{{{
  let a:bundle.dummy_commands = []
  for command in map(copy(neobundle#util#convert2list(
        \ a:bundle.autoload.commands)), "
        \ type(v:val) == type('') ?
          \ { 'name' : v:val } : v:val
          \")

    " Define dummy commands.
    silent! execute 'command ' . (get(command, 'complete', '') != '' ?
          \ ('-complete=' . command.complete) : '')
          \ . ' -bang -range -nargs=*' command.name printf(
          \ "call neobundle#autoload#command(%s, %s, <q-args>,
          \  expand('<bang>'), expand('<line1>'), expand('<line2>'))",
          \   string(command.name), string(a:bundle.name))

    call add(a:bundle.dummy_commands, command.name)
  endfor
endfunction"}}}
function! s:add_dummy_mappings(bundle) "{{{
  let a:bundle.dummy_mappings = []
  for [modes, mappings] in map(neobundle#util#convert2list(
        \ copy(a:bundle.autoload.mappings)), "
        \   type(v:val) == type([]) ?
        \     [v:val[0], v:val[1:]] : ['nxo', [v:val]]
        \ ")

    for mapping in mappings
      " Define dummy mappings.
      for mode in filter(split(modes, '\zs'),
            \ "index(['n', 'v', 'x', 'o', 'i', 'c'], v:val) >= 0")
        let mapping_str = substitute(mapping, '<', '<lt>', 'g')
        silent! execute mode.'noremap <unique><silent>' mapping printf(
              \ (mode ==# 'c' ? "\<C-r>=" :
              \  (mode ==# 'i' ? "\<C-o>:" : ":\<C-u>")."call ").
              \   "neobundle#autoload#mapping(%s, %s, %s)<CR>",
              \   string(mapping_str), string(a:bundle.name), string(mode))

        call add(a:bundle.dummy_mappings, [mode, mapping])
      endfor
    endfor
  endfor
endfunction"}}}

function! s:on_source(bundle) "{{{
  if a:bundle.verbose && a:bundle.lazy
    redraw
    echo 'source:' a:bundle.name
  endif
  call neobundle#call_hook('on_source', a:bundle)

  " Reload script files.
  for directory in filter(
        \ ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin'],
        \ "isdirectory(a:bundle.rtp.'/'.v:val)")
    for file in split(glob(a:bundle.rtp.'/'.directory.'/**/*.vim'), '\n')
      silent! source `=file`
    endfor
  endfor

  if exists('#'.a:bundle.augroup.'#VimEnter')
    execute 'silent doautocmd' a:bundle.augroup 'VimEnter'

    if has('gui_running') && &term ==# 'builtin_gui'
      execute 'silent doautocmd' a:bundle.augroup 'GUIEnter'
    endif
  endif

  if a:bundle.verbose && a:bundle.lazy
    redraw
    echo 'sourced:' a:bundle.name
  endif
endfunction"}}}

function! s:clear_dummy(bundle) "{{{
endfunction"}}}

function! s:is_reset_ftplugin(filetype, rtp) "{{{
  for filetype in split(a:filetype, '\.')
    for directory in ['ftplugin', 'indent', 'syntax',
          \ 'after/ftplugin', 'after/indent', 'after/syntax']
      let base = a:rtp . '/' . directory
      if filereadable(base.'/'.filetype.'.vim') ||
            \ (directory =~# 'ftplugin$' &&
            \   isdirectory(base . '/' . filetype) ||
            \   glob(base.'/'.filetype.'_*.vim') != '')
        return 1
      endif
    endfor
  endfor

  return 0
endfunction"}}}

function! s:reset_ftplugin(filetype_out) "{{{
  filetype off

  if a:filetype_out =~# 'detection:ON'
        \ && a:filetype_out =~# 'plugin:ON'
        \ && a:filetype_out =~# 'indent:ON'
    silent! filetype plugin indent on
  else
    if a:filetype_out =~# 'detection:ON'
      silent! filetype on
    endif

    if a:filetype_out =~# 'plugin:ON'
      silent! filetype plugin on
    endif

    if a:filetype_out =~# 'indent:ON'
      silent! filetype indent on
    endif
  endif

  if a:filetype_out =~# 'detection:ON'
    filetype detect
  endif

  " Reload filetype plugins.
  let &l:filetype = &l:filetype
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
