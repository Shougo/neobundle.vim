"=============================================================================
" FILE: neobundle_search.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 06 Oct 2012.
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

function! unite#sources#neobundle_search#define()"{{{
  " Init sources.
  if !exists('s:neobundle_sources')
    let s:neobundle_sources = {}
    for define in map(split(globpath(&runtimepath,
          \ 'autoload/neobundle/sources/*.vim', 1), '\n'),
          \ "neobundle#sources#{fnamemodify(v:val, ':t:r')}#define()")
      for dict in (type(define) == type([]) ? define : [define])
        if !empty(dict) && !has_key(s:neobundle_sources, dict.name)
          let s:neobundle_sources[dict.name] = dict
        endif
      endfor
      unlet define
    endfor
  endif

  return s:source
endfunction"}}}

let s:repository_cache = {}

" Source rec.
let s:source = {
      \ 'name' : 'neobundle/search',
      \ 'description' : 'search plugins for neobundle',
      \ 'hooks' : {},
      \ 'action_table' : {},
      \ 'default_action' : 'yank',
      \ 'max_candidates' : 50,
      \ 'syntax' : 'uniteSource__NeoBundleSearch',
      \ 'parents' : ['uri'],
      \ }

function! s:source.hooks.on_init(args, context)"{{{
  let a:context.source__sources = copy(s:neobundle_sources)
  if !empty(a:args)
    let a:context.source__sources = filter(
          \ a:context.source__sources,
          \ 'index(a:args, v:key) >= 0')
  endif
endfunction"}}}
function! s:source.gather_candidates(args, context)"{{{
  let candidates = []

  for source in values(a:context.source__sources)
    let candidates += source.gather_candidates(a:args, a:context)
  endfor

  return candidates
endfunction"}}}

function! s:source.complete(args, context, arglead, cmdline, cursorpos)"{{{
  let arglead = get(a:args, -1, '')
  return filter(keys(s:neobundle_sources),
        \ "stridx(v:val, arglead) == 0")
endfunction"}}}

function! s:source.hooks.on_syntax(args, context)"{{{
  syntax match uniteSource__NeoBundleSearch_DescriptionLine
        \ / -- .*$/
        \ contained containedin=uniteSource__NeoBundleSearch
  syntax match uniteSource__NeoBundleSearch_Description
        \ /.*$/
        \ contained containedin=uniteSource__NeoBundleSearch_DescriptionLine
  syntax match uniteSource__NeoBundleSearch_Marker
        \ / -- /
        \ contained containedin=uniteSource__NeoBundleSearch_DescriptionLine
  syntax match uniteSource__NeoBundleSearch_Marker
        \ / Installed /
        \ contained containedin=uniteSource__NeoBundleSearch
  highlight default link uniteSource__NeoBundleSearch_Name Statement
  highlight default link uniteSource__NeoBundleSearch_Marker Special
  highlight default link uniteSource__NeoBundleSearch_Description Comment
endfunction"}}}

" Actions"{{{
let s:source.action_table.yank = {
      \ 'description' : 'yank plugin settings',
      \ 'is_selectable' : 1,
      \ }
function! s:source.action_table.yank.func(candidates)"{{{
  let @" = join(map(a:candidates,
        \ "'NeoBundle ' . s:get_neobundle_args(v:val)"), "\n")
  if has('clipboard')
    let @* = @"
  endif

  echo 'Yanked plugin settings!'
endfunction"}}}

let s:source.action_table.install = {
      \ 'description' : 'direct install plugins',
      \ 'is_selectable' : 1,
      \ 'is_invalidate_cache' : 1,
      \ 'is_quit' : 0,
      \ }
function! s:source.action_table.install.func(candidates)"{{{
  for candidate in a:candidates
    execute 'NeoBundleDirectInstall'
          \ s:get_neobundle_args(candidate)
  endfor
endfunction"}}}
"}}}

" Filters"{{{
function! s:source.source__sorter(candidates, context)"{{{
  return s:sort_by(a:candidates, 'v:val.source__name')
endfunction"}}}
function! s:source.source__converter(candidates, context)"{{{
  let max_plugin_name = max(map(copy(a:candidates),
        \ 'len(v:val.source__name)'))
  let format = '%-'. max_plugin_name .'s %s'

  for candidate in a:candidates
    let candidate.abbr = printf(format,
        \          candidate.source__name,
        \          (neobundle#is_installed(candidate.source__name) ?
        \           'Installed' : candidate.source__description))
    let candidate.action__path = candidate.action__uri
  endfor

  return a:candidates
endfunction"}}}

let s:source.filters =
      \ ['matcher_default', s:source.source__sorter,
      \      s:source.source__converter]
"}}}

" Misc."{{{
function! s:sort_by(list, expr)
  let pairs = map(a:list, printf('[v:val, %s]', a:expr))
  return map(s:sort(pairs,
        \      'a:a[1] == a:b[1] ? 0 : a:a[1] > a:b[1] ? 1 : -1'), 'v:val[0]')
endfunction

" Sorts a list with expression to compare each two values.
" a:a and a:b can be used in {expr}.
function! s:sort(list, expr)
  if type(a:expr) == type(function('function'))
    return sort(a:list, a:expr)
  endif
  let s:expr = a:expr
  return sort(a:list, 's:_compare')
endfunction

function! s:_compare(a, b)
  return eval(s:expr)
endfunction

function! s:get_neobundle_args(candidate)
  return string(a:candidate.source__path)
          \  . (empty(a:candidate.source__options) ?
          \    '' : ', ' . string(a:candidate.source__options))
endfunction
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
