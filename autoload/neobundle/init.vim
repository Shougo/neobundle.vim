"=============================================================================
" FILE: init.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 17 Jan 2014.
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
  let bundle = a:bundle
  if !has_key(bundle, 'type') && get(bundle, 'local', 0)
    " Default type.
    let bundle.type = 'nosync'
  endif
  if !has_key(bundle, 'type')
    call neobundle#installer#error(
          \ printf('Failed parse name "%s" and args %s',
          \   a:bundle.orig_name, string(a:bundle.orig_opts)))
    return {}
  endif
  if !has_key(bundle, 'autoload')
    " Auto set autoload keys.
    let bundle.autoload = {}

    for key in filter([
          \ 'filetypes', 'filename_patterns',
          \ 'commands', 'functions', 'mappings', 'unite_sources',
          \ 'insert', 'explorer', 'on_source', 'function_prefix',
          \ ], 'has_key(bundle, v:val)')
      let bundle.autoload[key] = bundle[key]
      call remove(bundle, key)
    endfor
  endif

  let bundle = extend(bundle, s:get_default(), 'keep')

  if !has_key(bundle, 'name')
    let bundle.name = neobundle#util#name_conversion(bundle.orig_name)
  endif

  if !has_key(bundle, 'normalized_name')
    let normalized_name = fnamemodify(bundle.name, ':r')
    let normalized_name = substitute(normalized_name,
          \ '^vim-', '', '')
    let normalized_name = substitute(normalized_name,
          \ '-vim$', '', '')
    let bundle.normalized_name = normalized_name
  endif
  if !has_key(bundle.orig_opts, 'name') &&
     \ g:neobundle#enable_name_conversion
    " Use normalized name.
    let bundle.name = bundle.normalized_name
  endif

  if !has_key(bundle, 'directory')
    let bundle.directory = bundle.name
  endif

  let bundle.base = s:expand_path(bundle.base)
  if bundle.base =~ '[/\\]$'
    " Chomp.
    let bundle.base = substitute(bundle.base, '[/\\]\+$', '', '')
  endif
  if bundle.rev != ''
    let bundle.directory .= '_' . substitute(bundle.rev,
          \ '[^[:alnum:]_.-]', '', 'g')
  endif

  let bundle.path = isdirectory(bundle.uri) ?
        \ bundle.uri : bundle.base.'/'.bundle.directory

  let rtp = bundle.rtp
  " Check relative path.
  let bundle.rtp = (rtp =~ '^\%([~/]\|\a\+:\)') ?
        \ s:expand_path(rtp) : (bundle.path.'/'.rtp)
  if bundle.rtp =~ '[/\\]$'
    " Chomp.
    let bundle.rtp = substitute(bundle.rtp, '[/\\]\+$', '', '')
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

  if !has_key(bundle.autoload, 'function_prefix')
        \ && isdirectory(bundle.rtp . '/autoload')
    let bundle.autoload.function_prefix =
          \ neobundle#parser#_function_prefix(bundle.name)
  endif
  if !has_key(bundle, 'augroup')
    let bundle.augroup = bundle.name
  endif

  " Parse depends.
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

  if neobundle#config#is_sourced(bundle.name)
    let bundle.sourced = 1
  endif

  return bundle
endfunction"}}}

if neobundle#util#is_windows()
  function! s:expand_path(path)
    return neobundle#util#substitute_path_separator(
          \ simplify(expand(escape(a:path, '*?{}'), 1)))
  endfunction
else
  function! s:expand_path(path)
    return simplify(expand(escape(a:path, '*?{}'), 1))
  endfunction
endif

function! s:get_default() "{{{
  if !exists('s:default_bundle')
    let s:default_bundle = {
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
          \ 'hooks' : {},
          \ 'called_hooks' : {},
          \ 'external_commands' : {},
          \ 'autoload' : {},
          \ 'description' : '',
          \ 'dummy_commands' : [],
          \ 'dummy_mappings' : [],
          \ 'sourced' : 0,
          \ 'disabled' : 0,
          \ 'local' : 0,
          \ 'orig_name' : '',
          \ 'vim_version' : '',
          \ 'orig_opts' : {},
          \ 'recipe' : '',
          \ }
  endif

  let s:default_bundle.base = neobundle#get_neobundle_dir()

  return deepcopy(s:default_bundle)
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

