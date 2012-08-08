"=============================================================================
" FILE: neobundle_search.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 08 Aug 2012.
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

function! unite#sources#neobundle_search#define()"{{{
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

function! s:source.gather_candidates(args, context)"{{{
  if !executable('curl') && !executable('wget')
    call unite#print_error('[neobundle/search] curl or wget is not available!')
    return []
  endif

  let repository = 'http://vim-scripts.org/api/scripts_recent.json'

  call unite#print_message(
        \ '[neobundle/search] repository: ' . repository)

  let plugins = s:get_repository_plugins(a:context, repository)

  return map(copy(plugins), "{
        \ 'word' : v:val.n . ' ' . v:val.s,
        \ 'abbr' : printf('%-20s %-10s %-5s -- %s',
        \          v:val.n, v:val.t, v:val.rv, v:val.s),
        \ 'source__name' : v:val.n,
        \ 'source__type' : v:val.t,
        \ 'source__version' : v:val.rv,
        \ 'source__description' : v:val.s,
        \ 'action__uri' : 'https://github.com/vim-scripts/' . v:val.n,
        \ 'action__path' : 'https://github.com/vim-scripts/' . v:val.n,
        \ }")
endfunction"}}}

function! s:source.hooks.on_syntax(args, context)"{{{
  syntax match uniteSource__NeoBundleSearch_Name
        \ /\S\+\ze\s\+\w\+\s\+\s\+\w*/
        \ contained containedin=uniteSource__NeoBundleSearch
  syntax match uniteSource__NeoBundleSearch_DescriptionLine
        \ / -- .*$/
        \ contained containedin=uniteSource__NeoBundleSearch
  syntax match uniteSource__NeoBundleSearch_Description
        \ /.*$/
        \ contained containedin=uniteSource__NeoBundleSearch_DescriptionLine
  syntax match uniteSource__NeoBundleSearch_Marker
        \ / -- /
        \ contained containedin=uniteSource__NeoBundleSearch_DescriptionLine
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
  let @" = join(map(copy(a:candidates),
        \ "'NeoBundle '''.v:val.source__name.''''"), "\n")
  if has('clipboard')
    let @* = @"
  endif

  echo 'Yanked plugin settings!'
endfunction"}}}
"}}}

" Filters"{{{
function! s:source.source__converter(candidates, context)"{{{
  let max = max(map(copy(a:candidates),
        \ 'len(v:val.source__name)'))
  let format = '%-'. max .'s %-10s %-5s -- %s'

  for candidate in a:candidates
    let candidate.abbr = printf(format,
        \          candidate.source__name, candidate.source__type,
        \          candidate.source__version,
        \          candidate.source__description)
    let candidate.action__uri =
          \ 'https://github.com/vim-scripts/' . candidate.source__name
    let candidate.action__path = candidate.action__uri
  endfor

  return a:candidates
endfunction"}}}

let s:source.filters =
      \ ['matcher_default', 'sorter_default',
      \      s:source.source__converter]
"}}}

" Misc.
function! s:get_repository_plugins(context, path)"{{{
  let cache_dir = neobundle#get_neobundle_dir() . '/.neobundle'

  if a:context.is_redraw || !s:Cache.filereadable(cache_dir, a:path)
    " Reload cache.
    let cache_path = s:Cache.getfilename(cache_dir, a:path)

    call unite#print_message(
          \ '[neobundle/search] Reloading cache from ' . a:path)
    redraw

    if executable('curl')
      let cmd = 'curl --fail -s -o "' . cache_path . '" '. a:path
    elseif executable('wget')
      let cmd = 'wget -q -O "' . cache_path . '" ' . a:path
    endif

    let result = unite#util#system(cmd)

    if unite#util#get_last_status()
      call unite#print_message('[neobundle/search] ' . cmd)
      call unite#print_error('[neobundle/search] Error occured!')
      call unite#print_error(result)
      return []
    else
      call unite#print_message('[neobundle/search] Done!')
    endif
  endif

  if !has_key(s:repository_cache, a:path)
    sandbox let s:repository_cache[a:path] =
          \ eval(s:Cache.readfile(cache_dir, a:path)[0])
  endif

  return s:repository_cache[a:path]
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
