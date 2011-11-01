"=============================================================================
" FILE: config.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 01 Nov 2011.
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

let s:V = vital#of('neobundle')

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

function! neobundle#config#bundle(arg, ...)
  let bundle = neobundle#config#init_bundle(a:arg, a:000)
  let path = bundle.path
  if has_key(s:neobundles, path)
    call s:rtp_rm(path)
  endif

  let s:neobundles[path] = bundle
  call s:rtp_add(path)
endfunction

function! neobundle#config#rm_bndle(path)
  if has_key(s:neobundles, a:path)
    call s:rtp_rm(s:neobundles[a:path].path)
    call remove(s:neobundles, a:path)
  endif
endfunction

function! s:rtp_rm_all_bundles()
  call filter(values(s:neobundles), 's:rtp_rm(v:val.path)')
endfunction

function! s:rtp_rm(dir)
  execute 'set rtp-='.fnameescape(expand(a:dir))
  execute 'set rtp-='.fnameescape(expand(a:dir.'/after'))
endfunction

function! s:rtp_add(dir) abort
  execute 'set rtp^='.fnameescape(expand(a:dir))
  execute 'set rtp+='.fnameescape(expand(a:dir.'/after'))
endfunction

function! neobundle#config#init_bundle(name, opts)
  let bundle = extend(s:parse_options(a:opts),
        \ s:parse_name(substitute(a:name,"['".'"]\+','','g')))
  let bundle.path = s:expand_path(neobundle#get_neobundle_dir().'/'.
        \ get(bundle, 'directory', bundle.name))
  let bundle.orig_name = a:name
  let bundle.orig_opts = a:opts

  return extend(copy(s:bundle_base), bundle)
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
  if a:arg =~ '^\s*\(gh\|github\):\S\+\|^\w[[:alnum:]-]*/[^/]\+$'
    let uri = 'git://github.com/'.split(a:arg, ':')[-1]
    let name = substitute(split(uri, '/')[-1], '\.git\s*$','','i')
    let type = 'git'
  elseif a:arg =~ '^\s*\(git@\|git://\)\S\+'
        \   || a:arg =~ '\(file\|https\?\|svn\)://'
        \   || a:arg =~ '\.git\s*$'
    let uri = a:arg
    let name = split(substitute(uri, '/\?\.git\s*$','','i'), '/')[-1]
    if uri =~? 'svn'
      let type = 'svn'
    elseif uri =~? 'hg' || uri =~? 'https\?://bitbucket'
      let type = 'hg'
    else
      let type = 'git'
    endif
  else
    let name = a:arg
    let uri  = 'git//github.com/vim-scripts/'.name.'.git'
    let type = 'git'
  endif

  return { 'name': name, 'uri': uri, 'type' : type }
endfunction

function! s:expand_path(path)
  return simplify(expand(a:path))
endfunction

let s:bundle_base = {}

function! s:bundle_base.has_doc()
  let path = self.path
  return isdirectory(path.'/doc')
  \   && (!filereadable(path.'/doc/tags') || filewritable(path.'/doc/tags'))
  \   && (glob(path.'/doc/*.txt') != '' || glob(path.'/doc/*.??x') != '')
endfunction

function! s:bundle_base.helptags()
  try
    helptags `=self.path . '/doc/'`
  catch
    call s:V.print_error('Error generating helptags in '.self.path)
    call s:V.print_error(v:exception . ' ' . v:throwpoint)
  endtry
endfunction

