"=============================================================================
" FILE: parser.vim
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

function! neobundle#parser#bundle(arg, ...) "{{{
  let bundle = s:parse_arg(a:arg)
  let is_parse_only = get(a:000, 0, 0)
  if empty(bundle) || is_parse_only
    return bundle
  endif

  call neobundle#config#add(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#lazy(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  " Update lazy flag.
  let bundle.lazy = 1
  let bundle.resettable = 0
  for depend in bundle.depends
    let depend.lazy = bundle.lazy
    let depend.resettable = 0
  endfor

  call neobundle#config#add(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#fetch(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  " Clear runtimepath.
  let bundle.rtp = ''

  call neobundle#config#add(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#depends(arg) "{{{
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  if !neobundle#config#is_installed(bundle.name)
    let bundle.overwrite = 0
    let bundle.resettable = 0

    call neobundle#config#add(bundle)

    " Install bundle automatically.
    silent call neobundle#installer#install(0, bundle.name)
  endif

  " Load scripts.
  call neobundle#config#source(bundle.name)

  return bundle
endfunction"}}}

function! neobundle#parser#direct(arg) "{{{
  let bundle = neobundle#parser#bundle(a:arg, 1)

  if empty(bundle)
    return {}
  endif

  if !empty(neobundle#get(bundle.name))
    call neobundle#util#print_error(
          \ bundle.name . ' is already installed.')
    return {}
  endif

  call neobundle#config#add(bundle)

  call neobundle#config#save_direct(a:arg)

  " Direct install.
  call neobundle#installer#install(0, bundle.name)

  return bundle
endfunction"}}}

function! s:parse_arg(arg) "{{{
  let arg = type(a:arg) == type([]) ?
   \ string(a:arg) : '[' . a:arg . ']'
  sandbox let args = eval(arg)
  if empty(args)
    return {}
  endif

  let bundle = neobundle#parser#_init_bundle(
        \ args[0], args[1:])
  if empty(bundle)
    return {}
  endif

  let bundle.orig_arg = copy(a:arg)

  return bundle
endfunction"}}}

function! neobundle#parser#_init_bundle(name, opts) "{{{
  let path = neobundle#util#expand(
        \ substitute(a:name, "['".'"]\+', '', 'g'))
  let opts = s:parse_options(a:opts)
  let bundle = extend(neobundle#parser#path(
        \ path, opts), opts)

  let bundle.orig_name = a:name
  let bundle.orig_path = path
  let bundle.orig_opts = opts

  let bundle = neobundle#init#_bundle(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#local(localdir, options) "{{{
  for dir in map(filter(split(glob(fnamemodify(
        \ neobundle#util#expand(a:localdir), ':p')
        \ . '*'), '\n'), "isdirectory(v:val)"),
        \ "neobundle#util#substitute_path_separator(
        \   substitute(fnamemodify(v:val, ':p'), '/$', '', ''))")
    call neobundle#parser#bundle([dir,
          \ extend({
          \   'local' : 1,
          \   'base' : neobundle#util#substitute_path_separator(
          \              fnamemodify(a:localdir, ':p')), }, a:options)])
  endfor
endfunction"}}}

function! neobundle#parser#path(path, ...) "{{{
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
    let types = neobundle#config#get_types()
  endif

  for type in types
    let detect = type.detect(path, opts)

    if !empty(detect)
      return detect
    endif
  endfor

  if isdirectory(path)
    " Detect nosync type.
    return { 'name' : split(path, '/')[-1],
          \  'uri' : path, 'type' : 'nosync' }
  endif

  return {}
endfunction"}}}

function! neobundle#parser#_function_prefix(name) "{{{
  let function_prefix = tolower(fnamemodify(a:name, ':r'))
  let function_prefix = substitute(function_prefix,
        \'^vim-', '','')
  let function_prefix = substitute(function_prefix,
        \'^unite-', 'unite#sources#','')
  let function_prefix = substitute(function_prefix,
        \'-', '_', 'g')
  return function_prefix
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

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
