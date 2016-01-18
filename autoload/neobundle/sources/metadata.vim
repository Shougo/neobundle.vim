"=============================================================================
" FILE: metadata.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
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

let s:Cache = vital#of('unite').import('System.Cache')

let s:repository_cache = []

function! neobundle#sources#metadata#define() "{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'metadata',
      \ 'short_name' : 'meta',
      \ }

function! s:source.gather_candidates(args, context) "{{{
  let repository =
        \ 'https://gist.githubusercontent.com/Shougo/'
        \ . '028d6ae320cc8f354f88/raw/'
        \ . '3b62ad42d39a4d3d4f236a45e00eb6b03ca23352/vim-pi.json'

  call unite#print_message(
        \ '[neobundle/search:metadata] repository: ' . repository)

  let plugins = s:get_repository_plugins(a:context, repository)

  try
    return map(copy(plugins), "{
        \ 'word' : v:val.name . ' ' . v:val.description,
        \ 'source__name' : v:val.name,
        \ 'source__path' : v:val.repository,
        \ 'source__script_type' : s:convert2script_type(v:val.raw_type),
        \ 'source__description' : v:val.description,
        \ 'source__options' : [],
        \ 'action__uri' : v:val.uri,
        \ }")
  catch
    call unite#print_error(
          \ '[neobundle/search:metadata] '
          \ .'Error occurred in loading cache.')
    call unite#print_error(
          \ '[neobundle/search:metadata] '
          \ .'Please re-make cache by <Plug>(unite_redraw) mapping.')
    call neobundle#installer#error(v:exception . ' ' . v:throwpoint)

    return []
  endtry
endfunction"}}}

" Misc.
function! s:get_repository_plugins(context, path) "{{{
  let cache_dir = neobundle#get_neobundle_dir() . '/.neobundle'

  if a:context.is_redraw || !s:Cache.filereadable(cache_dir, a:path)
    " Reload cache.
    let cache_path = s:Cache.getfilename(cache_dir, a:path)

    call unite#print_message(
          \ '[neobundle/search:metadata] '
          \ .'Reloading cache from ' . a:path)
    redraw

    if s:Cache.filereadable(cache_dir, a:path)
      call delete(cache_path)
    endif

    let temp = unite#util#substitute_path_separator(tempname())

    let cmd = neobundle#util#wget(a:path, temp)
    if cmd =~# '^E:'
      call unite#print_error(
            \ '[neobundle/search:metadata] '.
            \ 'curl or wget command is not available!')
      return []
    endif

    let result = unite#util#system(cmd)

    if unite#util#get_last_status()
      call unite#print_message(
            \ '[neobundle/search:metadata] ' . cmd)
      call unite#print_message(
            \ '[neobundle/search:metadata] ' . result)
      call unite#print_error(
            \ '[neobundle/search:metadata] Error occurred!')
      return []
    elseif !filereadable(temp)
      call unite#print_error('[neobundle/search:metadata] '.
            \ 'Temporary file was not created!')
      return []
    else
      call unite#print_message('[neobundle/search:metadata] Done!')
    endif

    sandbox let data = eval(get(readfile(temp), 0, '[]'))

    " Convert cache data.
    call s:Cache.writefile(cache_dir, a:path,
          \ [string(values(s:convert_metadata(data)))])

    call delete(temp)
  endif

  if empty(s:repository_cache)
    sandbox let s:repository_cache =
          \ eval(get(s:Cache.readfile(cache_dir, a:path), 0, '[]'))
  endif

  return s:repository_cache
endfunction"}}}

function! s:convert_metadata(data) "{{{
  return map(copy(a:data), "{
        \ 'name' : v:key,
        \ 'raw_type' : get(v:val, 'script-type', ''),
        \ 'repository' : substitute(v:val.url, '^git://', 'https://', ''),
        \ 'description' : '',
        \ 'uri' : get(v:val, 'homepage', ''),
        \ }")
endfunction"}}}

function! s:convert2script_type(type) "{{{
  if a:type ==# 'utility'
    return 'plugin'
  elseif a:type ==# 'color scheme'
    return 'colors'
  else
    return a:type
  endif
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
