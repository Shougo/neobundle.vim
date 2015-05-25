"=============================================================================
" FILE: init.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
"          Copyright (C) 2010 http://github.com/gmarik
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

function! neobundle#init#_rc(path) "{{{
  let path =
        \ neobundle#util#substitute_path_separator(
        \ neobundle#util#expand(a:path))
  if path =~ '/$'
    let path = path[: -2]
  endif
  call neobundle#set_neobundle_dir(path)

  " Join to the tail in runtimepath.
  let rtp = neobundle#get_rtp_dir()
  execute 'set rtp-='.fnameescape(rtp)
  let rtps = neobundle#util#split_rtp(&runtimepath)
  let n = index(rtps, $VIMRUNTIME)
  let &runtimepath = neobundle#util#join_rtp(
        \ insert(rtps, rtp, n-1), &runtimepath, rtp)

  augroup neobundle
    autocmd!
  augroup END

  call neobundle#config#init()
  call neobundle#autoload#init()
endfunction"}}}

function! neobundle#init#_bundle(bundle) "{{{
  if !has_key(a:bundle, 'type') && get(a:bundle, 'local', 0)
    " Default type.
    let a:bundle.type = 'nosync'
  endif
  if !has_key(a:bundle, 'type')
    call neobundle#installer#error(
          \ printf('Failed parse name "%s" and args %s',
          \   a:bundle.orig_name, string(a:bundle.orig_opts)))
    return {}
  endif

  let bundle = {
          \ 'uri' : '',
          \ 'script_type' : '',
          \ 'rev' : '',
          \ 'rtp' : '',
          \ 'depends' : [],
          \ 'lazy' : 0,
          \ 'force' : 0,
          \ 'gui' : 0,
          \ 'terminal' : 0,
          \ 'overwrite' : 1,
          \ 'stay_same' : 0,
          \ 'autoload' : {},
          \ 'hooks' : {},
          \ 'called_hooks' : {},
          \ 'external_commands' : {},
          \ 'build_commands': {},
          \ 'description' : '',
          \ 'dummy_commands' : [],
          \ 'dummy_mappings' : [],
          \ 'sourced' : 0,
          \ 'disabled' : 0,
          \ 'local' : 0,
          \ 'focus' : 0,
          \ 'verbose' : 0,
          \ 'orig_name' : '',
          \ 'vim_version' : '',
          \ 'orig_opts' : {},
          \ 'recipe' : '',
          \ 'base' : neobundle#get_neobundle_dir(),
          \ 'install_rev' : '',
          \ 'install_process_timeout'
          \    : g:neobundle#install_process_timeout,
          \ }
  call extend(bundle, a:bundle)

  if !has_key(bundle, 'name')
    let bundle.name = neobundle#util#name_conversion(bundle.orig_name)
  endif

  if !has_key(bundle, 'normalized_name')
    let bundle.normalized_name = substitute(
          \ fnamemodify(bundle.name, ':r'),
          \ '\c^vim[_-]\|[_-]vim$', '', 'g')
  endif
  if !has_key(bundle.orig_opts, 'name') &&
     \ g:neobundle#enable_name_conversion
    " Use normalized name.
    let bundle.name = bundle.normalized_name
  endif

  if !has_key(bundle, 'directory')
    let bundle.directory = bundle.name

    if bundle.rev != ''
      let bundle.directory .= '_' . substitute(bundle.rev,
            \ '[^[:alnum:]_-]', '_', 'g')
    endif
  endif

  if bundle.base[0] == '~'
    let bundle.base = neobundle#util#expand(bundle.base)
  endif
  if bundle.base[-1] == '/' || bundle.base[-1] == '\'
    " Chomp.
    let bundle.base = bundle.base[: -2]
  endif

  let bundle.path = isdirectory(bundle.uri) ?
        \ bundle.uri : bundle.base.'/'.bundle.directory

  " Check relative path.
  if bundle.rtp !~ '^\%([~/]\|\a\+:\)'
    let bundle.rtp = bundle.path.'/'.bundle.rtp
  endif
  if bundle.rtp[0] == '~'
    let bundle.rtp = neobundle#util#expand(bundle.rtp)
  endif
  if bundle.rtp[-1] == '/' || bundle.rtp[-1] == '\'
    " Chomp.
    let bundle.rtp = bundle.rtp[: -2]
  endif
  if bundle.normalized_name ==# 'neobundle'
    " Do not add runtimepath.
    let bundle.rtp = ''
  endif

  if bundle.script_type != ''
    " Add script_type.
    " Note: To check by neobundle#config#is_installed().
    let bundle.path .= '/' . bundle.script_type
  endif

  if !has_key(bundle, 'resettable')
    let bundle.resettable = !bundle.lazy
  endif

  if !has_key(bundle, 'augroup')
    let bundle.augroup = bundle.name
  endif

  " Parse depends.
  if !empty(bundle.depends)
    call s:init_depends(bundle)
  endif

  if get(neobundle#config#get(bundle.name), 'sourced', 0)
    let bundle.sourced = 1
  endif

  if type(bundle.disabled) == type('')
    sandbox let bundle.disabled = eval(bundle.disabled)
  endif

  let bundle.disabled = bundle.disabled
        \ || (bundle.gui && !has('gui_running'))
        \ || (bundle.terminal && has('gui_running'))
        \ || (bundle.vim_version != ''
        \     && s:check_version(bundle.vim_version))
        \ || (!empty(bundle.external_commands)
        \     && neobundle#config#check_commands(bundle.external_commands))

  return bundle
endfunction"}}}

function! s:init_depends(bundle) "{{{
  let bundle = a:bundle
  let _ = []

  for depend in neobundle#util#convert2list(bundle.depends)
    if type(depend) == type('')
      let depend = string(depend)
    endif

    let depend_bundle = type(depend) == type({}) ?
          \ depend : neobundle#parser#bundle(depend, 1)
    let depend_bundle.lazy = bundle.lazy
    let depend_bundle.resettable = bundle.resettable
    let depend_bundle.overwrite = 0
    call add(_, depend_bundle)

    unlet depend
  endfor

  let bundle.depends = _
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

let &cpo = s:save_cpo
unlet s:save_cpo

