"=============================================================================
" FILE: parser.vim
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

function! neobundle#parser#bundle(arg, ...) "{{{
  let bundle = s:parse_arg(a:arg)
  let is_parse_only = get(a:000, 0, 0)
  if !is_parse_only
    call neobundle#config#add(bundle)

    if !neobundle#config#within_block()
          \ && !bundle.lazy && has('vim_starting')
      call neobundle#util#print_error(
            \ '[neobundle] `NeoBundle` commands must be executed within' .
            \ ' a neobundle#begin/end block.  Please check your usage.')
    endif
  endif

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
  let bundle.orig_opts.lazy = 1
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

function! neobundle#parser#recipe(arg) "{{{
  " Parse args.
  let arg = type(a:arg) == type([]) ?
   \ string(a:arg) : '[' . a:arg . ']'
  sandbox let args = eval(arg)
  if empty(args)
    return {}
  endif

  let recipe = args[0]
  let recipe_bundle = neobundle#parser#_parse_recipe(recipe)
  if empty(recipe_bundle)
    return {}
  endif

  let bundle = neobundle#parser#_init_bundle(
        \ recipe_bundle.path,
        \ [extend(recipe_bundle, get(args, 1, {}))])
  if empty(bundle)
    return {}
  endif

  let bundle.orig_arg = copy(a:arg)

  call neobundle#config#add(bundle)

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
  call neobundle#commands#install(0, bundle.name)

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
  let path = substitute(a:name, "['".'"]\+', '', 'g')
  if path[0] == '~'
    let path = neobundle#util#expand(path)
  endif
  let opts = s:parse_options(a:opts)
  if !has_key(opts, 'recipe')
    let opts.recipe = ''
  endif
  let bundle = extend(neobundle#parser#path(
        \ path, opts), opts)
  if bundle.recipe != ''
    call extend(bundle,
          \ neobundle#parser#_parse_recipe(bundle.recipe), 'keep')
  endif

  let bundle.orig_name = a:name
  let bundle.orig_path = path
  let bundle.orig_opts = opts
  let bundle.orig_arg = string(a:name).', '.string(opts)

  let bundle = neobundle#init#_bundle(bundle)

  return bundle
endfunction"}}}

function! neobundle#parser#local(localdir, options, includes) "{{{
  let base = fnamemodify(neobundle#util#expand(a:localdir), ':p')
  let directories = []
  for glob in a:includes
    let directories += map(filter(split(glob(base . glob), '\n'),
          \ "isdirectory(v:val)"), "
          \ substitute(neobundle#util#substitute_path_separator(
          \   fnamemodify(v:val, ':p')), '/$', '', '')")
  endfor
  for dir in neobundle#util#uniq(directories)
    let options = extend({ 'local' : 1, 'base' : base }, a:options)
    let name = fnamemodify(dir, ':t')
    let bundle = neobundle#get(name)
    if !empty(bundle)
      call extend(options, copy(bundle.orig_opts))
      if bundle.lazy
        let options.lazy = 1
      endif

      " Remove from lazy runtimepath
      call filter(neobundle#config#get_lazy_rtp_bundles(),
            \ "fnamemodify(v:val.rtp, ':h:t') != name")
    endif

    call neobundle#parser#bundle([dir, options])
  endfor
endfunction"}}}

function! neobundle#parser#load_toml(filename, default) "{{{
  try
    let toml = neobundle#TOML#parse_file(neobundle#util#expand(a:filename))
  catch /vital: Text.TOML:/
    call neobundle#util#print_error(
          \ '[neobundle] Invalid toml format: ' . a:filename)
    call neobundle#util#print_error(v:exception)
    return 1
  endtry
  if type(toml) != type({}) || !has_key(toml, 'plugins')
    call neobundle#util#print_error(
          \ '[neobundle] Invalid toml file: ' . a:filename)
    return 1
  endif

  " Parse.
  for plugin in toml.plugins
    if !has_key(plugin, 'repository')
      call neobundle#util#print_error(
            \ '[neobundle] No repository plugin data: ' . a:filename)
      return 1
    endif

    let options = extend(plugin, a:default, 'keep')
    " echomsg plugin.repository
    " echomsg string(options)
    call neobundle#parser#bundle([plugin.repository, options])
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
    let types = empty(type) ? [] : [type]
  else
    let detect = neobundle#config#get_types('git').detect(path, opts)
    if !empty(detect)
      let detect.name = neobundle#util#name_conversion(path)
      return detect
    endif

    let types = neobundle#config#get_types()
  endif

  let detect = {}
  for type in types
    let detect = type.detect(path, opts)
    if !empty(detect)
      break
    endif
  endfor

  if empty(detect) && isdirectory(path)
    " Detect nosync type.
    return { 'uri' : path, 'type' : 'nosync' }
  endif

  if !empty(detect) && !has_key(detect, 'name')
    let detect.name = neobundle#util#name_conversion(path)
  endif

  return detect
endfunction"}}}

function! neobundle#parser#_function_prefix(name) "{{{
  let function_prefix = tolower(fnamemodify(a:name, ':r'))
  let function_prefix = substitute(function_prefix,
        \'^vim-\|-vim$', '','')
  let function_prefix = substitute(function_prefix,
        \'^unite-', 'unite#sources#','')
  let function_prefix = tr(function_prefix, '-', '_')
  return function_prefix
endfunction"}}}

function! s:parse_options(opts) "{{{
  if empty(a:opts)
    return has_key(g:neobundle#default_options, '_') ?
          \ copy(g:neobundle#default_options['_']) : {}
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

function! neobundle#parser#_parse_recipe(recipe) "{{{
  let recipe = a:recipe
  if recipe !~ '\.vimrecipe$'
    let recipe .= '.vimrecipe'
  endif

  if recipe !~ '^/\|^\w\+:'
    " Search from runtimepath.
    let path = get(split(globpath(&runtimepath,
        \ 'recipes/' . recipe, 1), '\n'), 0, '')
    if path == ''
      " Use name conversion.
      let recipe = neobundle#util#name_conversion(a:recipe)
      if recipe !~ '\.vimrecipe$'
        let recipe .= '.vimrecipe'
      endif

      let path = get(split(globpath(&runtimepath,
            \ 'recipes/' . recipe, 1), '\n'), 0, '')
    endif
  else
    let path = recipe
  endif

  if !filereadable(path)
    call neobundle#util#print_error(printf(
          \ '[neobundle] The recipe file "%s" is not found.', a:recipe))
    return {}
  endif

  sandbox let data = eval(join(filter(readfile(path),
          \ "v:val !~ '^\\s*\\%(#.*\\)\\?$'"), ''))

  if !has_key(data, 'name') || !has_key(data, 'path')
    call neobundle#util#print_error(
          \ '[neobundle] ' . path)
    call neobundle#util#print_error(
          \ '[neobundle] The recipe file format is wrong.')
    return {}
  endif

  let data.receipe_path = path

  " Initialize.
  let default = {
        \ 'options' : {},
        \ 'description' : '',
        \ 'website' : '',
        \ 'script_type' : '',
        \ }

  let data = extend(data, default, 'keep')

  return data
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
