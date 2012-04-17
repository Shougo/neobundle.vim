"=============================================================================
" FILE: config.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 17 Apr 2012.
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
endif

function! neobundle#config#init()
  call s:rtp_rm_all_bundles()
  let s:neobundles = {}
endfunction

function! neobundle#config#get_neobundles()
  return values(s:neobundles)
endfunction

function! neobundle#config#reload(bundles)
  if empty(a:bundles)
    return
  endif

  " Delete old g:loaded_xxx variables.
  for var_name in keys(g:)
    if var_name =~ '^loaded_'
      execute 'unlet!' var_name
    endif
  endfor

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
    for bundle in a:bundles
      if stridx(script, bundle.path) >= 0
        silent! execute 'source' script
      endif
    endfor
  endfor
endfunction

function! neobundle#config#bundle(arg)
  sandbox let args = eval('[' . a:arg . ']')
  if empty(args)
    return {}
  endif

  let bundle = neobundle#config#init_bundle(args[0], args[1:])
  let path = bundle.path
  if has_key(s:neobundles, path)
    call s:rtp_rm(bundle.rtp)
  endif

  let s:neobundles[path] = bundle
  call s:rtp_add(bundle.rtp)
  return bundle
endfunction

function! neobundle#config#external_bundle(arg, ...)
  let bundle = neobundle#config#init_bundle(a:arg, a:000)
  let path = bundle.path
  if !has_key(s:neobundles, path)
    let s:neobundles[path] = bundle
  endif
  return bundle
endfunction

function! neobundle#config#rm_bndle(path)
  if has_key(s:neobundles, a:path)
    call s:rtp_rm(s:neobundles[a:path].rtp)
    call remove(s:neobundles, a:path)
  endif
endfunction

function! s:rtp_rm_all_bundles()
  call filter(values(s:neobundles), 's:rtp_rm(v:val.path)')
endfunction

function! s:rtp_rm(dir)
  execute 'set rtp-='.fnameescape(neobundle#util#expand(a:dir))
  execute 'set rtp-='.fnameescape(neobundle#util#expand(a:dir.'/after'))
endfunction

function! s:rtp_add(dir) abort
  execute 'set rtp^='.fnameescape(neobundle#util#expand(a:dir))
  execute 'set rtp+='.fnameescape(neobundle#util#expand(a:dir.'/after'))
endfunction

function! neobundle#config#init_bundle(name, opts)
  let bundle = extend(s:parse_name(substitute(a:name,"['".'"]\+','','g')),
        \ s:parse_options(a:opts))
  let bundle.base = s:expand_path(get(bundle, 'base',
        \ neobundle#get_neobundle_dir()))
  let bundle.path = s:expand_path(bundle.base.'/'.
        \ get(bundle, 'directory', bundle.name))
  let bundle.rtp = s:expand_path(bundle.path.'/'.get(bundle, 'rtp', ''))
  if bundle.rtp =~ '[/\\]$'
    " Chomp.
    let bundle.rtp = bundle.rtp[: -2]
  endif
  let bundle.orig_name = a:name
  let bundle.orig_opts = a:opts

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

