"=============================================================================
" FILE: github.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 02 Mar 2013.
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

function! neobundle#sources#github#define() "{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'github',
      \ 'short_name' : 'github',
      \ }

function! s:source.gather_candidates(args, context) "{{{
  if !executable('curl') && !executable('wget')
    call unite#print_error(
          \ '[neobundle/search:github] '.
          \ 'curl or wget command is not available!')
    return []
  endif

  let plugins = s:get_github_searches(a:context.source__input)

  return map(copy(plugins), "{
        \ 'word' : v:val.username.'/'.v:val.name . ' ' . v:val.description,
        \ 'source__name' : (v:val.fork ? '| ' : '') .
        \          v:val.username.'/'.v:val.name,
        \ 'source__path' : v:val.username.'/'.v:val.name,
        \ 'source__description' : v:val.description,
        \ 'source__options' : [],
        \ 'action__uri' : 'https://github.com/' .
        \        v:val.username.'/'.v:val.name,
        \ }")
endfunction"}}}

" Misc.
function! s:get_github_searches(string) "{{{
  let path = 'https://api.github.com/legacy/repos/search/'
        \ . a:string . '*?language=VimL'
  let temp = neobundle#util#substitute_path_separator(tempname())

  let cmd = printf('%s "%s" "%s"', (executable('curl') ?
          \ 'curl --fail -s -o' : 'wget -q -O '), temp, path)

  call unite#print_message(
        \ '[neobundle/search:github] Searching plugins from github...')
  redraw

  let result = unite#util#system(cmd)

  if unite#util#get_last_status()
    call unite#print_message('[neobundle/search:github] ' . cmd)
    call unite#print_error('[neobundle/search:github] Error occured!')
    call unite#print_error(result)
    return []
  elseif !filereadable(temp)
    call unite#print_error('[neobundle/search:github] '.
          \ 'Temporary file was not created!')
    return []
  else
    call unite#print_message('[neobundle/search:github] Done!')
  endif

  let [true, false, null] = [1,0,"''"]
  sandbox let data = eval(join(readfile(temp)))
  call filter(data.repositories,
        \ "stridx(v:val.username.'/'.v:val.name, a:string) >= 0")

  call delete(temp)

  return data.repositories
endfunction"}}}

function! s:convert_vim_scripts_data(data) "{{{
  return map(copy(a:data), "{
        \ 'name' : v:val.n,
        \ 'raw_type' : v:val.t,
        \ 'repository' : v:val.rv,
        \ 'description' : printf('%-5s %s', v:val.rv, v:val.s),
        \ 'uri' : 'https://github.com/vim-scripts/' . v:val.n,
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
