"=============================================================================
" FILE: vamkr.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 29 Dec 2013.
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

let s:vamkr = {}

if !exists('*vamkr#AddCopyHook')
  " Dummy function.
  function! vamkr#AddCopyHook(repository, files)
    for [filename, type] in items(a:files)
      " Todo: Support multiple files?
      let a:repository.url .= '/' . type . '/' . filename
    endfor

    " echomsg string(a:repository)
    return a:repository
  endfunction
endif

function! neobundle#vamkr#init() "{{{
  let head = 'https://raw.github.com/MarcWeber/'
        \.'vim-addon-manager-known-repositories/master/db/'

  let s:vamkr.id2name = neobundle#vamkr#parse(head .
        \ 'script-id-to-name-log.json')
  let s:vamkr.vimorgsources = neobundle#vamkr#parse(head .
        \ 'vimorgsources.json')
  let s:vamkr.scm_generated = neobundle#vamkr#parse(head .
        \ 'scm_generated.json')
  let s:vamkr.patchinfo = neobundle#vamkr#parse(head .
        \ 'patchinfo.vim')
  let s:vamkr.scmsources = neobundle#vamkr#parse(head .
        \ 'scmsources.vim')
endfunction"}}}

function! neobundle#vamkr#parse(path) "{{{
  let cache_dir = neobundle#get_neobundle_dir() . '/.neobundle'
  let cache_path = neobundle#cache#getfilename(cache_dir, a:path)

  if !neobundle#cache#filereadable(cache_dir, a:path)
    " Reload cache.

    call neobundle#installer#log(
          \ '[neobundle/search:vim-scripts.org] Reloading cache from ' . a:path)
    redraw

    if neobundle#cache#filereadable(cache_dir, a:path)
      call delete(cache_path)
    endif

    if executable('curl')
      let cmd = 'curl --fail -s -o "' . cache_path . '" '. a:path
    elseif executable('wget')
      let cmd = 'wget -q -O "' . cache_path . '" ' . a:path
    else
      call neobundle#util#print_error(
            \ 'curl or wget command is not available!')
      return []
    endif

    let result = neobundle#util#system(cmd)

    if !filereadable(cache_path)
      call unite#print_error('Cache file was not created!')
      return []
    else
      call neobundle#installer#log('Done!')
    endif
  endif

  if fnamemodify(a:path, ':e') == 'vim'
    " Vim script.
    unlet! g:r
    sandbox execute 'source' fnameescape(cache_path)
    sandbox let data = g:r
  else
    " JSON.
    sandbox let data = eval(join(readfile(cache_path)))
  endif

  return data
endfunction"}}}

" __END__
" vim: foldmethod=marker
