"=============================================================================
" FILE: commands.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 25 Feb 2014.
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
" Version: 3.0, for Vim 7.2
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

function! neobundle#commands#helptags(bundles) "{{{
  if neobundle#util#is_sudo()
    call neobundle#util#print_error(
          \ '"sudo vim" is detected. This feature is disabled.')
    return
  endif

  let help_dirs = filter(copy(a:bundles), 's:has_doc(v:val.rtp)')

  if !empty(help_dirs)
    call s:update_tags()

    if !has('vim_starting')
      call neobundle#installer#log(
            \ '[neobundle/install] Helptags: done. '
            \ .len(help_dirs).' bundles processed')
    endif
  endif

  return help_dirs
endfunction"}}}

function! neobundle#commands#check() "{{{
  if neobundle#installer#get_tags_info() !=#
        \ sort(map(neobundle#config#get_neobundles(), 'v:val.name'))
    " Recache automatically.
    NeoBundleDocs
  endif

  if !neobundle#exists_not_installed_bundles()
    return
  endif

  if has('gui_running') && has('vim_starting')
    " Note: :NeoBundleCheck cannot work in GUI startup.
    autocmd neobundle VimEnter * NeoBundleCheck
  else
    echomsg 'Not installed bundles: '
          \ string(neobundle#get_not_installed_bundle_names())
    if confirm('Install bundles now?', "yes\nNo", 2) == 1
      call neobundle#installer#install(0, '')
    endif
    echo ''
  endif
endfunction"}}}

function! neobundle#commands#clean(bang, ...) "{{{
  if neobundle#util#is_sudo()
    call neobundle#util#print_error(
          \ '"sudo vim" is detected. This feature is disabled.')
    return
  endif

  if get(a:000, 0, '') == ''
    let all_dirs = filter(split(neobundle#util#substitute_path_separator(
          \ globpath(neobundle#get_neobundle_dir(), '*', 1)), "\n"),
          \ 'isdirectory(v:val)')
    let bundle_dirs = map(copy(neobundle#config#get_neobundles()),
          \ "(v:val.script_type != '') ?
          \  v:val.base . '/' . v:val.directory : v:val.path")
    let x_dirs = filter(all_dirs,
          \ "!neobundle#config#is_installed(fnamemodify(v:val, ':t'))
          \ && index(bundle_dirs, v:val) < 0 && v:val !~ '/neobundle.vim$'")
  else
    let x_dirs = map(neobundle#config#search_simple(a:000), 'v:val.path')
    if len(x_dirs) > len(a:000)
      " Check bug.
      call neobundle#util#print_error('Bug: x_dirs = %s but arguments is %s',
            \ string(x_dirs), map(copy(a:000), 'v:val.path'))
      return
    endif
  endif

  if empty(x_dirs)
    call neobundle#installer#log('[neobundle/install] All clean!')
    return
  end

  if a:bang || s:check_really_clean(x_dirs)
    if !has('vim_starting')
      redraw
    endif
    let result = neobundle#util#system(g:neobundle#rm_command . ' ' .
          \ join(map(copy(x_dirs), '"\"" . v:val . "\""'), ' '))
    if neobundle#util#get_last_status()
      call neobundle#installer#error(result)
    endif

    for dir in x_dirs
      call neobundle#config#rm(dir)
    endfor

    call s:update_tags()
  endif
endfunction"}}}

function! neobundle#commands#reinstall(bundle_names) "{{{
  let bundles = neobundle#config#search_simple(split(a:bundle_names))

  if empty(bundles)
    call neobundle#installer#error(
          \ '[neobundle/install] Target bundles not found.')
    call neobundle#installer#error(
          \ '[neobundle/install] You may have used the wrong bundle name.')
    return
  endif

  call neobundle#installer#reinstall(bundles)
endfunction"}}}

function! neobundle#commands#complete_bundles(arglead, cmdline, cursorpos) "{{{
  return filter(map(neobundle#config#get_neobundles(), 'v:val.name'),
        \ 'stridx(tolower(v:val), tolower(a:arglead)) >= 0')
endfunction"}}}

function! neobundle#commands#complete_lazy_bundles(arglead, cmdline, cursorpos) "{{{
  return filter(map(filter(neobundle#config#get_neobundles(),
        \ "!neobundle#config#is_sourced(v:val.name) && v:val.rtp != ''"), 'v:val.name'),
        \ 'stridx(tolower(v:val), tolower(a:arglead)) == 0')
endfunction"}}}

function! neobundle#commands#complete_deleted_bundles(arglead, cmdline, cursorpos) "{{{
  let bundle_dirs = map(copy(neobundle#config#get_neobundles()), 'v:val.path')
  let all_dirs = split(neobundle#util#substitute_path_separator(
        \ globpath(neobundle#get_neobundle_dir(), '*', 1)), "\n")
  let x_dirs = filter(all_dirs, 'index(bundle_dirs, v:val) < 0')

  return filter(map(x_dirs, "fnamemodify(v:val, ':t')"),
        \ 'stridx(v:val, a:arglead) == 0')
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo
