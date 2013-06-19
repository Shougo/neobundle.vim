"=============================================================================
" FILE: neobundle_search.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 19 Jun 2013.
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

let s:Cache = vital#of('unite.vim').import('System.Cache')

function! unite#sources#neobundle_search#define() "{{{
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

let s:plugin_names = []

" Source rec.
let s:source = {
      \ 'name' : 'neobundle/search',
      \ 'description' : 'search plugins for neobundle',
      \ 'hooks' : {},
      \ 'action_table' : {},
      \ 'default_action' : 'yank',
      \ 'max_candidates' : 200,
      \ 'syntax' : 'uniteSource__NeoBundleSearch',
      \ 'parents' : ['uri'],
      \ }

function! s:source.hooks.on_init(args, context) "{{{
  let a:context.source__sources = copy(s:neobundle_sources)
  if !empty(a:args)
    let a:context.source__sources = filter(
          \ a:context.source__sources,
          \ 'index(a:args, v:key) >= 0')
  endif

  let a:context.source__input = a:context.input
  if a:context.source__input == ''
    let a:context.source__input =
          \ unite#util#input('Please input search word: ', '',
          \ 'customlist,unite#sources#neobundle_search#complete_plugin_names')
  endif
endfunction"}}}
function! s:source.gather_candidates(args, context) "{{{
  call unite#print_source_message('Search word: '
        \ . a:context.source__input, s:source.name)

  let candidates = []
  let a:context.source__source_names = []

  let s:plugin_names = []

  for source in values(a:context.source__sources)
    let source_candidates = source.gather_candidates(a:args, a:context)
    let source_name = get(source, 'short_name', source.name)
    for candidate in source_candidates
      let candidate.source__source = source_name
      if !has_key(candidate, 'source__script_type')
        let candidate.source__script_type = ''
      endif
      if !has_key(candidate, 'source__description')
        let candidate.source__description = ''
      endif
    endfor

    let candidates += source_candidates
    call add(a:context.source__source_names, source_name)

    let s:plugin_names += map(copy(source_candidates), 'v:val.source__name')
  endfor

  call s:initialize_plugin_names(a:context)

  return filter(candidates,
        \ 'stridx(v:val.word, a:context.source__input) >= 0')
endfunction"}}}

function! s:source.complete(args, context, arglead, cmdline, cursorpos) "{{{
  let arglead = get(a:args, -1, '')
  return filter(keys(s:neobundle_sources),
        \ "stridx(v:val, arglead) == 0")
endfunction"}}}

function! s:source.hooks.on_syntax(args, context) "{{{
  syntax match uniteSource__NeoBundleSearch_DescriptionLine
        \ / -- .*$/
        \ contained containedin=uniteSource__NeoBundleSearch
  syntax match uniteSource__NeoBundleSearch_Description
        \ /.*$/
        \ contained containedin=uniteSource__NeoBundleSearch_DescriptionLine
  syntax match uniteSource__NeoBundleSearch_Marker
        \ / -- /
        \ contained containedin=uniteSource__NeoBundleSearch_DescriptionLine
  syntax match uniteSource__NeoBundleSearch_Install
        \ / Installed /
        \ contained containedin=uniteSource__NeoBundleSearch
  highlight default link uniteSource__NeoBundleSearch_Install Statement
  highlight default link uniteSource__NeoBundleSearch_Marker Special
  highlight default link uniteSource__NeoBundleSearch_Description Comment
endfunction"}}}

" Actions "{{{
let s:source.action_table.yank = {
      \ 'description' : 'yank plugin settings',
      \ 'is_selectable' : 1,
      \ }
function! s:source.action_table.yank.func(candidates) "{{{
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
      \ 'is_quit' : 0,
      \ }
function! s:source.action_table.install.func(candidates) "{{{
  for candidate in a:candidates
    execute 'NeoBundleDirectInstall' s:get_neobundle_args(candidate)
  endfor
endfunction"}}}
"}}}

" Filters "{{{
function! s:source.source__sorter(candidates, context) "{{{
  return s:sort_by(a:candidates, 'v:val.source__name')
endfunction"}}}
function! s:source.source__converter(candidates, context) "{{{
  let max_plugin_name = max(map(copy(a:candidates),
        \ 'len(v:val.source__name)'))
  let max_script_type = max(map(copy(a:candidates),
        \ 'len(v:val.source__script_type)'))
  let max_source_name = max(map(copy(a:context.source__source_names),
        \ 'len(v:val)'))
  let format = '%-'. max_plugin_name .'s %-'.
        \ max_source_name .'s %-'. max_script_type .'s -- %s'

  for candidate in a:candidates
    let candidate.abbr = printf(format,
        \          candidate.source__name, candidate.source__source,
        \          candidate.source__script_type,
        \          (neobundle#is_installed(candidate.source__name) ?
        \           'Installed' : candidate.source__description))
    let candidate.is_multiline = 1
    let candidate.kind =
          \ get(candidate, 'action__path', '') != '' ?
          \ 'file' : 'common'
  endfor

  return a:candidates
endfunction"}}}

let s:source.filters =
      \ ['matcher_default', s:source.source__sorter,
      \      s:source.source__converter]
"}}}

" Misc. "{{{
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
          \  . (a:candidate.source__description == '' ? '' :
          \      ' " ' . a:candidate.source__description)
endfunction

function! unite#sources#neobundle_search#complete_plugin_names(arglead, cmdline, cursorpos) "{{{
  return filter(s:get_plugin_names(), "stridx(v:val, a:arglead) == 0")
endfunction"}}}

function! s:initialize_plugin_names(context) "{{{
  let cache_dir = neobundle#get_neobundle_dir() . '/.neobundle'
  let path = 'plugin_names'

  if a:context.is_redraw || !s:Cache.filereadable(cache_dir, path)
    " Convert cache data.
    call s:Cache.writefile(cache_dir, path, [string(s:plugin_names)])
  endif

  return s:get_plugin_names()
endfunction"}}}

function! s:get_plugin_names() "{{{
  let cache_dir = neobundle#get_neobundle_dir() . '/.neobundle'
  let path = 'plugin_names'

  if empty(s:plugin_names) && s:Cache.filereadable(cache_dir, path)
    sandbox let s:plugin_names =
          \ eval(get(s:Cache.readfile(cache_dir, path), 0, '[]'))
  endif

  return neobundle#util#uniq(s:plugin_names)
endfunction"}}}
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
