"=============================================================================
" FILE: neobundle.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 07 Mar 2012.
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

" Create vital module for neobundle
let s:V = vital#of('neobundle.vim')

function! s:system(...)
  return call(s:V.system, a:000, s:V)
endfunction

function! s:get_last_status(...)
  return call(s:V.get_last_status, a:000, s:V)
endfunction

function! unite#sources#neobundle#define()"{{{
  return unite#util#has_vimproc() ? s:source : {}
endfunction"}}}

let s:source = {
      \ 'name' : 'neobundle',
      \ 'description' : 'candidates from bundles',
      \ 'hooks' : {},
      \ 'action_table' : {},
      \ 'default_action' : 'update',
      \ }

function! s:source.hooks.on_init(args, context)"{{{
  let bundle_names = filter(copy(a:args), 'v:val != "!"')
  let a:context.source__bang =
        \ index(a:args, '!') >= 0
  let a:context.source__bundles = empty(bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(bundle_names)
endfunction"}}}

function! s:source.gather_candidates(args, context)"{{{
  let max = max(map(copy(neobundle#config#get_neobundles()), 'len(v:val.name)'))
  let _ = []
  for bundle in neobundle#config#get_neobundles()
    let dict = {
        \ 'word' : printf('%-'.max.'s : %s',
        \         bundle.name, s:get_commit_status(
        \         a:context.source__bang, bundle)),
        \ 'kind' : 'directory',
        \ 'action__path' : bundle.path,
        \ 'action__directory' : bundle.path,
        \ 'action__bundle' : bundle,
        \ 'action__bundle_name' : bundle.name,
        \ }
    call add(_, dict)
  endfor

  return _
endfunction"}}}

function! s:get_commit_status(bang, bundle)
  if !isdirectory(a:bundle.path)
    return 'Not installed'
  endif

  if a:bang && !neobundle#util#is_windows()
        \ || !a:bang && neobundle#util#is_windows()
    return neobundle#util#substitute_path_separator(
          \ fnamemodify(a:bundle.path, ':~'))
  endif

  if a:bundle.type == 'svn'
    " Todo:
    return ''
  elseif a:bundle.type == 'hg'
    " Todo:
    return ''
  elseif a:bundle.type == 'git'
    let cmd = 'git log -1 --pretty=format:''%h [%cr] %s'''
  else
    return ''
  endif

  let cwd = getcwd()

  lcd `=a:bundle.path`

  let output = s:system(cmd)

  lcd `=cwd`

  if s:get_last_status()
    return printf('Error(%d) occured when executing "%s"',
          \ s:get_last_status(), cmd)
  endif

  return output
endfunction

" Actions"{{{
let s:source.action_table.update = {
      \ 'description' : 'update bundles',
      \ 'is_selectable' : 1,
      \ }
function! s:source.action_table.update.func(candidates)"{{{
  call unite#start([['neobundle/install', '!']
        \ + map(copy(a:candidates), 'v:val.action__bundle_name')])
endfunction"}}}
let s:source.action_table.delete = {
      \ 'description' : 'delete bundles',
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ 'is_selectable' : 1,
      \ }
function! s:source.action_table.delete.func(candidates)"{{{
  call call('neobundle#installer#clean', insert(map(copy(a:candidates),
        \ 'v:val.action__bundle_name'), 0))
endfunction"}}}
let s:source.action_table.reinstall = {
      \ 'description' : 'reinstall bundles',
      \ 'is_selectable' : 1,
      \ }
function! s:source.action_table.reinstall.func(candidates)"{{{
  for candidate in a:candidates
    " Save info.
    let name = candidate.action__bundle.orig_name
    let opts = candidate.action__bundle.orig_opts

    " Remove.
    call neobundle#installer#clean(1, candidate.action__bundle_name)

    call call('neobundle#config#bundle', [name] + opts)
  endfor

  " Install.
  call unite#start([['neobundle/install', '!']
        \ + map(copy(a:candidates), 'v:val.action__bundle_name')])
endfunction"}}}
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
