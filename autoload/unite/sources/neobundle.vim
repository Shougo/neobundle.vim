"=============================================================================
" FILE: neobundle.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 30 Aug 2012.
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

function! unite#sources#neobundle#define()"{{{
  return unite#util#has_vimproc() ? s:source : {}
endfunction"}}}

let s:source = {
      \ 'name' : 'neobundle',
      \ 'description' : 'candidates from bundles',
      \ 'hooks' : {},
      \ }

function! s:source.hooks.on_init(args, context)"{{{
  let bundle_names = filter(copy(a:args), 'v:val != "!"')
  let a:context.source__bang =
        \ index(a:args, '!') >= 0
  let a:context.source__bundles = empty(bundle_names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(bundle_names)
endfunction"}}}

" Filters"{{{
function! s:source.source__converter(candidates, context)"{{{
  for candidate in a:candidates
    if candidate.source__uri =~
          \ '^\%(https\?\|git\)://github.com/'
      let candidate.action__uri = candidate.source__uri
      let candidate.action__uri =
            \ substitute(candidate.action__uri, '^git://', 'https://', '')
      let candidate.action__uri =
            \ substitute(candidate.action__uri, '.git$', '', '')
    endif
  endfor

  return a:candidates
endfunction"}}}

let s:source.filters =
      \ ['matcher_default', 'sorter_default',
      \      s:source.source__converter]
"}}}

function! s:source.gather_candidates(args, context)"{{{
  let _ = map(a:context.source__bundles, "{
        \ 'word' : substitute(v:val.orig_name,
        \  '^\%(https\?\|git\)://\%(github.com/\)\?', '', ''),
        \ 'kind' : 'neobundle',
        \ 'action__path' : v:val.path,
        \ 'action__directory' : v:val.path,
        \ 'action__bundle' : v:val,
        \ 'action__bundle_name' : v:val.name,
        \ 'source__uri' : v:val.uri,
        \ }
        \")

  let max = max(map(copy(_), 'len(v:val.word)'))

  for candidate in _
    let candidate.word = printf('%-'.max.'s : %s',
          \         candidate.word, s:get_commit_status(
          \         a:context.source__bang, candidate.action__bundle))
  endfor

  return _
endfunction"}}}

function! s:get_commit_status(bang, bundle)"{{{
  if !isdirectory(a:bundle.path)
    return 'Not installed'
  endif

  if a:bang && !neobundle#util#is_windows()
        \ || !a:bang && neobundle#util#is_windows()
    return neobundle#util#substitute_path_separator(
          \ fnamemodify(a:bundle.path, ':~'))
  endif

  let types = neobundle#config#get_types()
  let cmd = types[a:bundle.type].get_revision_number_command(a:bundle)
  if cmd == ''
    return ''
  endif

  let cwd = getcwd()

  lcd `=a:bundle.path`

  let output = neobundle#util#system(cmd)

  lcd `=cwd`

  if neobundle#util#get_last_status()
    return printf('Error(%d) occured when executing "%s"',
          \ neobundle#util#get_last_status(), cmd)
  endif

  return output
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
