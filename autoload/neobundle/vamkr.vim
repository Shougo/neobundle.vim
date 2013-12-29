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
  let snr_to_name = {}
  call map(copy(s:vamkr.vimorgsources),
        \ 'extend(snr_to_name, {v:val.vim_script_nr : v:key})')
  let s:vamkr.patchinfo = neobundle#vamkr#parse(head .
        \ 'patchinfo.vim')

  " Parse scheme
  let [scm, scmnr]= neobundle#vamkr#parse(head .
        \ 'scmsources.vim')
  let scm_generated = neobundle#vamkr#parse(head .
        \ 'scm_generated.json')
  call extend(scm, scm_generated, 'keep')

  call map(scmnr, "extend(scm, {snr_to_name[v:key] :
        \  extend(v:val, {'vim_script_nr': v:key})})")
  " Change dependencies.
  for depdict in map(filter(values(scm),
        \ "has_key(get(v:val, 'addon-info', {}), 'dependencies')"),
        \ "v:val['addon-info'].dependencies")
    for depname in filter(keys(depdict), 'v:val[0] is# "%"')
      call remove(depdict, depname)
      let depdict[snr_to_name[depname[1:]]] = {}
    endfor
  endfor

  let s:vamkr.scm = scm
endfunction"}}}

function! neobundle#vamkr#get(name) "{{{
  if empty(s:vamkr)
    call neobundle#vamkr#init()
  endif

  " Search from number.
  return has_key(s:vamkr.scm, a:name) ? s:vamkr.scm[a:name]
        \ : get(s:vamkr.vimorgsources, a:name, {})
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
    try
      execute "function! s:Vim()\n".join(
            \ readfile(cache_path, 'b'), "\n")."\nreturn r\nendfunction"

      sandbox let data = s:Vim()
    catch
      throw 'Execute error: '.v:exception
            \ .' error location ('.a:path.'): '.v:throwpoint
    finally
      silent! delfunction s:Vim
    endtry
  elseif fnamemodify(a:path, ':e') == 'json'
    " JSON.
    try
      sandbox let data = eval(join(readfile(cache_path, 'b'), ''))
    catch
      throw 'Failed to read json file: '.a:path
            \ .': '.v:exception.' '.v:throwpoint
    endtry
  else
    throw 'Unknown path: ' . a:path
  endif

  return data
endfunction"}}}

" __END__
" vim: foldmethod=marker
