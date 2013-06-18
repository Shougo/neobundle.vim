"=============================================================================
" FILE: parser.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 18 Jun 2013.
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

function! neobundle#parser#lazy(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  " Update lazy flag.
  let bundle.lazy = 1
  for depend in bundle.depends
    let depend.lazy = bundle.lazy
  endfor

  call s:add_bundle(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#fetch(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  " Clear runtimepath.
  let bundle.rtp = ''

  call s:add_bundle(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#depends(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  if !has_key(s:neobundles, bundle.name)
    let bundle.overwrite = 0
    let bundle.resettable = 0

    call s:add_bundle(bundle)

    " Install bundle automatically.
    silent call neobundle#installer#install(0, bundle.name)
  endif

  " Load scripts.
  call neobundle#config#source(bundle.name)

  return bundle
endfunction"}}}

function! neobundle#parser#direct(arg)
  let bundle = neobundle#config#bundle(a:arg)

  if empty(bundle)
    return {}
  endif

  let path = bundle.path

  let s:direct_neobundles[path] = bundle
  call neobundle#config#save_direct_bundles()

  " Direct install.
  call neobundle#installer#install(0, bundle.name)

  return bundle
endfunction

function! neobundle#parser#bundle(name, opts) "{{{
  let path = substitute(a:name, "['".'"]\+', '', 'g')
  let opts = s:parse_options(a:opts)
  let bundle = extend(neobundle#config#parse_path(
        \ path, opts), opts)

  let bundle.orig_name = a:name
  let bundle.orig_path = path
  let bundle.orig_opts = opts

  let bundle = s:init_bundle(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#arg(arg) "{{{
  let arg = type(a:arg) == type([]) ?
   \ string(a:arg) : '[' . a:arg . ']'
  sandbox let args = eval(arg)
  if empty(args)
    return {}
  endif

  let bundle = neobundle#config#init_bundle(
        \ args[0], args[1:])
  if empty(bundle)
    return {}
  endif

  let bundle.orig_arg = a:arg

  if !empty(bundle.external_commands)
    call neobundle#config#check_external_commands(bundle)
  endif

  return bundle
endfunction"}}}

function! neobundle#config#parser#path(path, ...) "{{{
  let opts = get(a:000, 0, {})
  let site = get(opts, 'site', g:neobundle#default_site)
  let path = substitute(a:path, '/$', '', '')

  if path !~ '^/\|^\a:' && path !~ ':'
    " Add default site.
    let path = site . ':' . path
  endif

  if has_key(opts, 'type')
    let type = neobundle#config#get_types(opts.type)
    if empty(type)
      return {}
    endif

    let types = [type]
  else
    let types = exists('s:neobundle_types') ?
          \ s:neobundle_types : neobundle#config#get_types()
  endif

  for type in types
    let detect = type.detect(path, opts)

    if !empty(detect)
      return detect
    endif
  endfor

  return {}
endfunction"}}}

function! s:parse_options(opts) "{{{
  if empty(a:opts)
    return get(g:neobundle#default_options, '_', {})
  endif

  if len(a:opts) == 3
    " rev, default, options
    let [rev, default, options] = a:opts
  elseif len(a:opts) == 2 && type(a:opts[-1]) == type('')
    " rev, default
    let [rev, default, options] = a:opts + [{}]
  elseif len(a:opts) == 2 && type(a:opts[-1]) == type({})
    " rev, options
    let [rev, default, options] = [a:opts[0], '', a:opts[1]]
  elseif len(a:opts) == 1 && type(a:opts[-1]) == type('')
    " rev
    let [rev, default, options] = [a:opts[0], '', {}]
  elseif len(a:opts) == 1 && type(a:opts[-1]) == type({})
    " options
    let [rev, default, options] = ['', '', a:opts[0]]
  else
    call neobundle#installer#error(
          \ printf('Invalid option : "%s".', string(a:opts)))
    return {}
  endif

  if rev != ''
    let options.rev = rev
  endif

  if !has_key(options, 'default')
    let options.default = (default == '') ?  '_' : default
  endif

  " Set default options.
  if has_key(g:neobundle#default_options, options.default)
    call extend(options,
          \ g:neobundle#default_options[options.default], 'keep')
  endif

  return options
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
          \ 'tail_path' : g:neobundle#enable_tail_path,
          \ 'script_type' : '',
          \ 'rev' : '',
          \ 'rtp' : '',
          \ 'depends' : [],
          \ 'lazy' : 0,
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
          \ 'orig_opts' : {},
          \ }
  endif

  let s:default_bundle.base = neobundle#get_neobundle_dir()

  return deepcopy(s:default_bundle)
endfunction"}}}

function! s:init_bundle(bundle) "{{{
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

  let bundle = extend(s:get_default(), bundle)

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
  if bundle.rev != ''
    let bundle.directory .= '_' . substitute(bundle.rev,
          \ '[^[:alnum:]_.-]', '', 'g')
  endif

  let bundle.path = s:expand_path(bundle.base.'/'.bundle.directory)

  let rtp = bundle.rtp
  " Check relative path.
  let bundle.rtp = (rtp =~ '^\%(/\|\~\|\a\+:\)') ?
        \ rtp : (bundle.path.'/'.rtp)
  let bundle.rtp = s:expand_path(bundle.rtp)
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

  let bundle.resettable = !bundle.lazy

  if !has_key(bundle.autoload, 'function_prefix')
        \ && isdirectory(bundle.rtp . '/autoload')
    let bundle.autoload.function_prefix =
          \ neobundle#config#parser#_function_prefix(bundle.name)
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
    let depend_bundle = neobundle#config#bundle(depend, 1)
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

function! neobundle#config#parser#_function_prefix(name) "{{{
  let function_prefix = tolower(fnamemodify(a:name, ':r'))
  let function_prefix = substitute(function_prefix,
        \'^vim-', '','')
  let function_prefix = substitute(function_prefix,
        \'^unite-', 'unite#sources#','')
  let function_prefix = substitute(function_prefix,
        \'-', '_', 'g')
  return function_prefix
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
