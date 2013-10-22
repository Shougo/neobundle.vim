"=============================================================================
" FILE: neobundle_vim_recipes.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 22 Oct 2013.
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

let s:repository_cache = []

function! neobundle#sources#neobundle_vim_recipes#define() "{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'neobundle-vim-recipes',
      \ 'short_name' : 'neobundle',
      \ }

function! s:source.gather_candidates(args, context) "{{{
  let plugins = s:get_repository_plugins(a:context)

  return map(copy(plugins), "{
        \ 'word' : v:val.name . ' ' . v:val.description,
        \ 'source__name' : v:val.name,
        \ 'source__description' : v:val.description,
        \ 'source__script_type' : v:val.script_type,
        \ 'source__options' : v:val.options,
        \ 'source__path' : v:val.path,
        \ 'action__path' : v:val.receipe_path,
        \ 'action__uri' : v:val.website,
        \ }")
endfunction"}}}

" Misc.
function! s:get_repository_plugins(context) "{{{
  if a:context.is_redraw || empty(s:repository_cache)
    " Reload cache.
    let s:repository_cache = []

    for path in split(globpath(&runtimepath,
          \ 'recipes/**/*.vimrecipe', 1), '\n')
      sandbox let data = eval(join(filter(readfile(path),
            \ "v:val !~ '^\\s*\\%(#.*\\)\\?$'"), ''))

      if !has_key(data, 'name') || !has_key(data, 'path')
        call unite#print_error(
              \ '[neobundle/search:neobundle-vim-recipes] ' . path)
        call unite#print_error(
              \ '[neobundle/search:neobundle-vim-recipes] ' .
              \ 'The recipe file format is wrong.')
        continue
      endif

      let data.receipe_path = path

      " Initialize.
      let default = {
            \ 'options' : {},
            \ 'description' : '',
            \ 'website' : '',
            \ 'script_type' : '',
            \ }

      let data = extend(data, default, 'keep')

      " Set options.
      for key in ['depends', 'rev', 'type', 'script_type',
            \ 'rtp', 'base', 'build', 'external_commands']
        if has_key(data, key)
          let data.options[key] = data[key]
        endif
      endfor

      call add(s:repository_cache, data)
    endfor
  endif

  return s:repository_cache
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
