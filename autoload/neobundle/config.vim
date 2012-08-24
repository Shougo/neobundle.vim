"=============================================================================
" FILE: config.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 24 Aug 2012.
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
" Version: 0.1, for Vim 7.2
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

if !exists('s:neobundles')
  let s:neobundles = {}
  let s:loaded_neobundles = {}
endif

function! neobundle#config#init()
  call s:rtp_rm_all_bundles()

  for bundle in values(s:neobundles)
    if bundle.resettable
      " Reset.
      call remove(s:neobundles, bundle.path)
      if neobundle#config#is_sourced(bundle.name)
        call remove(s:loaded_neobundles, bundle.name)
      endif
    endif
  endfor

  " Load neobundle types.
  let s:neobundle_types = {}
  for define in map(split(globpath(&runtimepath,
        \ 'autoload/neobundle/types/*.vim', 1), '\n'),
        \ "neobundle#types#{fnamemodify(v:val, ':t:r')}#define()")
    for dict in (type(define) == type([]) ? define : [define])
      if !empty(dict) && !has_key(s:neobundle_types, dict.name)
        let s:neobundle_types[dict.name] = dict
      endif
    endfor
    unlet define
  endfor
endfunction

function! neobundle#config#get_neobundles()
  return sort(values(s:neobundles), 's:compare_names')
endfunction

function! s:compare_names(a, b)
  return (a:a.name >? a:b.name) ? 1 : -1
endfunction

function! neobundle#config#reload(bundles)
  if empty(a:bundles)
    return
  endif

  call s:rtp_add_bundles(a:bundles)

  " Delete old g:loaded_xxx variables.
  for var_name in keys(g:)
    if var_name =~ '^loaded_'
      execute 'unlet!' var_name
    endif
  endfor

  silent! runtime! ftdetect/**/*.vim
  silent! runtime! after/ftdetect/**/*.vim
  silent! runtime! plugin/**/*.vim
  silent! runtime! after/plugin/**/*.vim

  " Reload autoload scripts.
  let scripts = []
  for line in split(s:redir('scriptnames'), "\n")
    let name = matchstr(line, '^\s*\d\+:\s\+\zs.\+\ze\s*$')
    if name != '' && name =~ '/autoload/'
          \ && name !~ '/unite.vim/\|/neobundle.vim/'
      call add(scripts, s:unify_path(name))
    endif
  endfor

  for script in scripts
    for bundle in filter(copy(a:bundles),
          \ 'stridx(script, v:val.path) >= 0')
      silent! execute source `=script`
    endfor
  endfor
endfunction

function! neobundle#config#bundle(arg)
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  let path = bundle.path
  if has_key(s:neobundles, path)
    call s:rtp_rm(bundle.rtp)
  endif

  let s:neobundles[path] = bundle
  let s:loaded_neobundles[bundle.name] = 1
  call s:rtp_add(bundle.rtp)
  for depend in bundle.depends
    if type(depend) == type('')
      let depend = string(depend)
    endif

    call neobundle#config#bundle(depend)

    unlet depend
  endfor

  return bundle
endfunction

function! neobundle#config#lazy_bundle(arg)
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  let path = bundle.path

  let s:neobundles[path] = bundle
  return bundle
endfunction

function! neobundle#config#depends_bundle(arg)
  let bundle = s:parse_arg(a:arg)

  if empty(bundle) || has_key(s:neobundles, bundle.path)
    " Ignore.
    return {}
  endif

  let bundle = neobundle#config#bundle(a:arg)
  let bundle.resettable = 0
  let s:loaded_neobundles[bundle.name] = 0

  " Install bundle automatically.
  silent call neobundle#installer#install(0, bundle.name)

  " Load scripts.
  call neobundle#config#source([bundle])

  return bundle
endfunction

function! s:parse_arg(arg)
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

  return bundle
endfunction

function! neobundle#config#source(...)
  let bundles = empty(a:000) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(a:000)
  let bundles = filter(bundles,
        \ '!neobundle#config#is_sourced(v:val.name)')
  if empty(bundles)
    return
  endif

  filetype off

  for bundle in bundles
    if has_key(s:neobundles, bundle.path)
      call s:rtp_rm(bundle.rtp)
    endif
    call s:rtp_add(bundle.rtp)

    for depend in bundle.depends
      if type(depend) == type('')
        let depend = string(depend)
      endif

      call neobundle#config#bundle(depend)

      unlet depend
    endfor

    for directory in
          \ ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin']
      for file in split(glob(bundle.rtp.'/'.directory.'/**/*.vim'), '\n')
        source `=file`
      endfor
    endfor

    if has_key(bundle, 'augroup') && exists('#'.bundle.augroup)
      execute 'doautocmd' bundle.augroup 'VimEnter'

      if has('gui_running')
        execute 'doautocmd' bundle.augroup 'GUIEnter'
      endif
    endif

    let s:loaded_neobundles[bundle.name] = 1
  endfor

  filetype plugin indent on

  " Reload filetype plugins.
  let &l:filetype = &l:filetype
endfunction

function! neobundle#config#is_sourced(name)
  return get(s:loaded_neobundles, a:name, 0)
endfunction

function! neobundle#config#rm_bundle(path)
  if has_key(s:neobundles, a:path)
    call s:rtp_rm(s:neobundles[a:path].rtp)
    call remove(s:neobundles, a:path)
  endif
endfunction

function! neobundle#config#get_types()
  return s:neobundle_types
endfunction

function! neobundle#config#parse_path(path)
  for type in values(neobundle#config#get_types())
    let detect = type.detect(a:path)
    if !empty(detect)
      return detect
    endif
  endfor

  return {}
endfunction

function! s:rtp_rm_all_bundles()
  call filter(filter(values(s:neobundles),
        \ "v:val.name !=# 'neobundle.vim'"), 's:rtp_rm(v:val.rtp)')
endfunction

function! s:rtp_rm(dir)
  execute 'set rtp-='.fnameescape(neobundle#util#expand(a:dir))
  execute 'set rtp-='.fnameescape(neobundle#util#expand(a:dir.'/after'))
endfunction

function! s:rtp_add_bundles(bundles)
  call filter(copy(a:bundles), 's:rtp_add(v:val.rtp)')
endfunction

function! s:rtp_add(dir) abort
  let rtp = neobundle#util#expand(a:dir)
  if isdirectory(rtp)
    execute 'set rtp^='.fnameescape(rtp)
  endif
  if isdirectory(rtp.'/after')
    execute 'set rtp+='.fnameescape(rtp.'/after')
  endif
endfunction

function! neobundle#config#init_bundle(name, opts)
  let path = substitute(a:name, "['".'"]\+', '', 'g')
  let bundle = extend(neobundle#config#parse_path(path),
        \ s:parse_options(a:opts))
  if !has_key(bundle, 'uri')
    let bundle.uri = path
  endif
  if !has_key(bundle, 'name')
    let bundle.name =
          \ substitute(split(path, '/')[-1], '\.git\s*$','','i')
  endif

  if !has_key(bundle, 'type')
    if !executable('git')
      call neobundle#installer#error(
            \ '[neobundle] git is not installed. You cannot install plugins from github.')
    endif

    call neobundle#installer#error(
          \ printf('Failed parse name "%s" and args %s',
          \   a:name, string(a:opts)))
    return {}
  endif

  let bundle.base = s:expand_path(get(bundle, 'base',
        \ neobundle#get_neobundle_dir()))
  let bundle.path = s:expand_path(bundle.base.'/'.
        \ get(bundle, 'directory', bundle.name))
  let bundle.rtp = s:expand_path(bundle.path.'/'.
        \ get(bundle, 'rtp', ''))
  if bundle.rtp =~ '[/\\]$'
    " Chomp.
    let bundle.rtp = substitute(bundle.rtp, '[/\\]\+$', '', '')
  endif

  let depends = get(bundle, 'depends', [])
  let bundle.depends = type(depends) == type('') ?
        \ [depends] : depends

  let bundle.orig_name = a:name
  let bundle.orig_opts = a:opts
  let bundle.resettable = 1

  return bundle
endfunction

function! neobundle#config#search(bundle_names)
  let bundles = []
  for bundle in neobundle#config#get_neobundles()
    if index(a:bundle_names, bundle.name) >= 0
      call add(bundles, bundle)
    endif
  endfor

  return bundles
endfunction

function! s:parse_options(opts)
  " TODO: improve this
  if empty(a:opts)
    return {}
  endif

  if type(a:opts[0]) == type({})
    return a:opts[0]
  else
    return { 'rev': a:opts[0] }
  endif
endfunction

function! s:parse_name(arg)
  if a:arg =~ '\<\(gh\|github\):\S\+\|^\w[[:alnum:]-]*/[^/]\+$'
    let uri = g:neobundle_default_git_protocol .
          \ '://github.com/'.split(a:arg, ':')[-1]
    if uri !~ '\.git\s*$'
      " Add .git suffix.
      let uri .= '.git'
    endif

    let name = substitute(split(uri, '/')[-1], '\.git\s*$','','i')
    let type = 'git'
  elseif a:arg =~ '\<\%(git@\|git://\)\S\+'
        \ || a:arg =~ '\<\%(file\|https\?\|svn\)://'
        \ || a:arg =~ '\.git\s*$'
    let uri = a:arg
    let name = split(substitute(uri, '/\?\.git\s*$','','i'), '/')[-1]

    if uri =~? '^git://'
      " Git protocol.
      let type = 'git'
    elseif uri =~? '/svn[/.]'
      let type = 'svn'
    elseif uri =~? '/hg[/.@]'
          \ || uri =~? '\<https\?://bitbucket\.org/'
          \ || uri =~? '\<https://code\.google\.com/'
      let type = 'hg'
    else
      " Assume git(may not..).
      let type = 'git'
    endif
  else
    let name = a:arg
    let uri  = g:neobundle_default_git_protocol .
          \ '://github.com/vim-scripts/'.name.'.git'
    let type = 'git'
  endif

  return { 'name': name, 'uri': uri, 'type' : type }
endfunction

function! s:expand_path(path)
  return neobundle#util#substitute_path_separator(
        \ simplify(neobundle#util#expand(a:path)))
endfunction

function! s:redir(cmd)
  redir => res
  silent! execute a:cmd
  redir END
  return res
endfunction

function! s:unify_path(path)
  return fnamemodify(resolve(a:path), ':p:gs?\\\+?/?')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

