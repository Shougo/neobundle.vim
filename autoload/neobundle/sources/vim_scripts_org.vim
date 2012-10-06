"=============================================================================
" FILE: vim_scripts_org.vim
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

let s:Cache = vital#of('unite.vim').import('System.Cache')

let s:repository_cache = {}

function! neobundle#sources#vim_scripts_org#define()"{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'vim-scripts.org',
      \ }

function! s:source.gather_candidates(args, context)"{{{
  if !executable('curl') && !executable('wget')
    call unite#print_error(
          \ '[neobundle/search:vim-scripts.org] curl or wget command is not available!')
    return []
  endif

  let repository = 'http://vim-scripts.org/api/scripts_recent.json'

  call unite#print_message(
        \ '[neobundle/search:vim-scripts.org] repository: ' . repository)

  let plugins = s:get_repository_plugins(a:context, repository)

  return map(copy(plugins), "{
        \ 'word' : v:val.name . ' ' . v:val.description,
        \ 'source__name' : v:val.name,
        \ 'source__description' : v:val.description,
        \ 'action__uri' : 'https://github.com/vim-scripts/' . v:val.uri,
        \ }")
endfunction"}}}

" Misc.
function! s:get_repository_plugins(context, path)"{{{
  let cache_dir = neobundle#get_neobundle_dir() . '/.neobundle'

  if a:context.is_redraw || !s:Cache.filereadable(cache_dir, a:path)
    " Reload cache.
    let cache_path = s:Cache.getfilename(cache_dir, a:path)

    call unite#print_message(
          \ '[neobundle/search:vim-scripts.org] Reloading cache from ' . a:path)
    redraw

    let temp = tempname()

    if executable('curl')
      let cmd = 'curl --fail -s -o "' . temp . '" '. a:path
    elseif executable('wget')
      let cmd = 'wget -q -O "' . temp . '" ' . a:path
    endif

    let result = unite#util#system(cmd)

    if unite#util#get_last_status()
      call unite#print_message('[neobundle/search:vim-scripts.org] ' . cmd)
      call unite#print_error('[neobundle/search:vim-scripts.org] Error occured!')
      call unite#print_error(result)
      return []
    else
      call unite#print_message('[neobundle/search:vim-scripts.org] Done!')
    endif

    sandbox let data = eval(readfile(temp)[0])

    " Convert cache data.
    call s:Cache.writefile(cache_dir, a:path,
          \ [string(s:convert_vim_scripts_data(data))])

    call delete(temp)
  endif

  if !has_key(s:repository_cache, a:path)
    sandbox let s:repository_cache[a:path] =
          \ eval(s:Cache.readfile(cache_dir, a:path)[0])
  endif

  return s:repository_cache[a:path]
endfunction"}}}

function! s:convert_vim_scripts_data(data)"{{{
  return map(copy(a:data), "{
        \ 'name' : v:val.n,
        \ 'raw_type' : v:val.t,
        \ 'repository' : v:val.rv,
        \ 'description' : printf('%-10s %-5s -- %s',
        \          v:val.t, v:val.rv, v:val.s),
        \ 'uri' : 'https://github.com/vim-scripts/' . v:val.n,
        \ }")
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
