"=============================================================================
" FILE: util.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
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

let s:is_windows = has('win32')
let s:is_cygwin = has('win32unix')
let s:is_mac = !s:is_windows
      \ && (has('mac') || has('macunix') || has('gui_macvim') ||
      \   (!isdirectory('/proc') && executable('sw_vers')))

function! neobundle#util#substitute_path_separator(path) "{{{
  return (s:is_windows && a:path =~ '\\') ?
        \ tr(a:path, '\', '/') : a:path
endfunction"}}}
function! neobundle#util#expand(path) "{{{
  let path = (a:path =~ '^\~') ? fnamemodify(a:path, ':p') :
        \ (a:path =~ '^\$\h\w*') ? substitute(a:path,
        \               '^\$\h\w*', '\=eval(submatch(0))', '') :
        \ a:path
  return (s:is_windows && path =~ '\\') ?
        \ neobundle#util#substitute_path_separator(path) : path
endfunction"}}}
function! neobundle#util#join_paths(path1, path2) "{{{
  " Joins two paths together, handling the case where the second path
  " is an absolute path.
  if s:is_absolute(a:path2)
    return a:path2
  endif
  if a:path1 =~ (s:is_windows ? '[\\/]$' : '/$') ||
        \ a:path2 =~ (s:is_windows ? '^[\\/]' : '^/')
    " the appropriate separator already exists
    return a:path1 . a:path2
  else
    " note: I'm assuming here that '/' is always valid as a directory
    " separator on Windows. I know Windows has paths that start with \\?\ that
    " diasble behavior like that, but I don't know how Vim deals with that.
    return a:path1 . '/' . a:path2
  endif
endfunction "}}}
if s:is_windows
  function! s:is_absolute(path) "{{{
    return a:path =~ '^[\\/]\|^\a:'
  endfunction "}}}
else
  function! s:is_absolute(path) "{{{
    return a:path =~ "^/"
  endfunction "}}}
endif

function! neobundle#util#is_windows() "{{{
  return s:is_windows
endfunction"}}}
function! neobundle#util#is_mac() "{{{
  return s:is_mac
endfunction"}}}
function! neobundle#util#is_cygwin() "{{{
  return s:is_cygwin
endfunction"}}}

" Sudo check.
function! neobundle#util#is_sudo() "{{{
  return $SUDO_USER != '' && $USER !=# $SUDO_USER
      \ && $HOME !=# expand('~'.$USER)
      \ && $HOME ==# expand('~'.$SUDO_USER)
endfunction"}}}

" Check vimproc. "{{{
function! neobundle#util#has_vimproc() "{{{
  if !exists('*vimproc#version')
    try
      call vimproc#version()
    catch
    endtry
  endif

  return exists('*vimproc#version')
endfunction"}}}
"}}}
" iconv() wrapper for safety.
function! s:iconv(expr, from, to) "{{{
  if a:from == '' || a:to == '' || a:from ==? a:to
    return a:expr
  endif
  let result = iconv(a:expr, a:from, a:to)
  return result != '' ? result : a:expr
endfunction"}}}
function! neobundle#util#system(str, ...) "{{{
  let command = a:str
  let input = a:0 >= 1 ? a:1 : ''
  let command = s:iconv(command, &encoding, 'char')
  let input = s:iconv(input, &encoding, 'char')

  if a:0 == 0
    let output = neobundle#util#has_vimproc() ?
          \ vimproc#system(command) : system(command, "\<C-d>")
  elseif a:0 == 1
    let output = neobundle#util#has_vimproc() ?
          \ vimproc#system(command, input) : system(command, input)
  else
    " ignores 3rd argument unless you have vimproc.
    let output = neobundle#util#has_vimproc() ?
          \ vimproc#system(command, input, a:2) : system(command, input)
  endif

  let output = s:iconv(output, 'char', &encoding)

  return substitute(output, '\n$', '', '')
endfunction"}}}
function! neobundle#util#get_last_status() "{{{
  return neobundle#util#has_vimproc() ?
        \ vimproc#get_last_status() : v:shell_error
endfunction"}}}

" Split a comma separated string to a list.
function! neobundle#util#split_rtp(runtimepath) "{{{
  if stridx(a:runtimepath, '\,') < 0
    return split(a:runtimepath, ',')
  endif

  let split = split(a:runtimepath, '\\\@<!\%(\\\\\)*\zs,')
  return map(split,'substitute(v:val, ''\\\([\\,]\)'', "\\1", "g")')
endfunction"}}}

function! neobundle#util#join_rtp(list, runtimepath, rtp) "{{{
  return (stridx(a:runtimepath, '\,') < 0 && stridx(a:rtp, ',') < 0) ?
        \ join(a:list, ',') : join(map(copy(a:list), 's:escape(v:val)'), ',')
endfunction"}}}

function! neobundle#util#split_envpath(path) "{{{
  let delimiter = neobundle#util#is_windows() ? ';' : ':'
  if stridx(a:path, '\' . delimiter) < 0
    return split(a:path, delimiter)
  endif

  let split = split(a:path, '\\\@<!\%(\\\\\)*\zs' . delimiter)
  return map(split,'substitute(v:val, ''\\\([\\'
        \ . delimiter . ']\)'', "\\1", "g")')
endfunction"}}}

function! neobundle#util#join_envpath(list, orig_path, add_path) "{{{
  let delimiter = neobundle#util#is_windows() ? ';' : ':'
  return (stridx(a:orig_path, '\' . delimiter) < 0
        \ && stridx(a:add_path, delimiter) < 0) ?
        \   join(a:list, delimiter) :
        \   join(map(copy(a:list), 's:escape(v:val)'), delimiter)
endfunction"}}}

" Removes duplicates from a list.
function! neobundle#util#uniq(list, ...) "{{{
  let list = a:0 ? map(copy(a:list), printf('[v:val, %s]', a:1)) : copy(a:list)
  let i = 0
  let seen = {}
  while i < len(list)
    let key = string(a:0 ? list[i][1] : list[i])
    if has_key(seen, key)
      call remove(list, i)
    else
      let seen[key] = 1
      let i += 1
    endif
  endwhile
  return a:0 ? map(list, 'v:val[0]') : list
endfunction"}}}

function! neobundle#util#set_default(var, val, ...)  "{{{
  if !exists(a:var) || type({a:var}) != type(a:val)
    let alternate_var = get(a:000, 0, '')

    let {a:var} = exists(alternate_var) ?
          \ {alternate_var} : a:val
  endif
endfunction"}}}
function! neobundle#util#set_dictionary_helper(variable, keys, pattern) "{{{
  for key in split(a:keys, '\s*,\s*')
    if !has_key(a:variable, key)
      let a:variable[key] = a:pattern
    endif
  endfor
endfunction"}}}

function! neobundle#util#get_filetypes() "{{{
  let filetype = exists('b:neocomplcache.context_filetype') ?
        \ b:neocomplcache.context_filetype : &filetype
  return split(filetype, '\.')
endfunction"}}}

function! neobundle#util#convert2list(expr) "{{{
  return type(a:expr) ==# type([]) ? a:expr : [a:expr]
endfunction"}}}

function! neobundle#util#print_error(expr) "{{{
  return s:echo(a:expr, 1)
endfunction"}}}

function! neobundle#util#redraw_echo(expr) "{{{
  return s:echo(a:expr, 0)
endfunction"}}}

function! s:echo(expr, is_error) "{{{
  let msg = neobundle#util#convert2list(a:expr)

  if has('vim_starting')
    let m = join(msg, "\n")
    if a:is_error
      echohl WarningMsg | echomsg m | echohl None
    else
      echo m
    endif
    return
  endif

  let more_save = &more
  let showcmd_save = &showcmd
  let ruler_save = &ruler
  try
    set nomore
    set noshowcmd
    set noruler

    let height = max([1, &cmdheight])
    for i in range(0, len(msg)-1, height)
      redraw

      let m = join(msg[i : i+height-1], "\n")
      if a:is_error
        echohl WarningMsg | echomsg m | echohl None
      else
        echo m
      endif
    endfor
  finally
    let &more = more_save
    let &showcmd = showcmd_save
    let &ruler = ruler_save
  endtry
endfunction"}}}

function! neobundle#util#name_conversion(path) "{{{
  return fnamemodify(split(a:path, ':')[-1], ':s?/$??:t:s?\c\.git\s*$??')
endfunction"}}}

" Escape a path for runtimepath.
function! s:escape(path)"{{{
  return substitute(a:path, ',\|\\,\@=', '\\\0', 'g')
endfunction"}}}

function! neobundle#util#unify_path(path) "{{{
  return fnamemodify(resolve(a:path), ':p:gs?\\\+?/?')
endfunction"}}}

function! neobundle#util#cd(path) "{{{
  if isdirectory(a:path)
    execute 'lcd' fnameescape(a:path)
  endif
endfunction"}}}

function! neobundle#util#writefile(path, list) "{{{
  let path = neobundle#get_neobundle_dir() . '/.neobundle/' . a:path
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir)
    call mkdir(dir, 'p')
  endif

  return writefile(a:list, path)
endfunction"}}}

function! neobundle#util#cleandir(path) "{{{
  let path = neobundle#get_neobundle_dir() . '/.neobundle/' . a:path

  for file in filter(split(globpath(path, '*', 1), '\n'),
        \ '!isdirectory(v:val)')
    call delete(file)
  endfor
endfunction"}}}

function! neobundle#util#copy_bundle_files(bundles, directory) "{{{
  " Delete old files.
  call neobundle#util#cleandir(a:directory)

  let files = {}
  for bundle in a:bundles
    for file in filter(split(globpath(
          \ bundle.rtp, a:directory.'/**', 1), '\n'),
          \ '!isdirectory(v:val)')
      let filename = fnamemodify(file, ':t')
      let files[filename] = readfile(file)
    endfor
  endfor

  for [filename, list] in items(files)
    if filename =~# '^tags\%(-.*\)\?$'
      call sort(list)
    endif
    call neobundle#util#writefile(a:directory . '/' . filename, list)
  endfor
endfunction"}}}

" Sorts a list using a set of keys generated by mapping the values in the list
" through the given expr.
" v:val is used in {expr}
function! neobundle#util#sort_by(list, expr) "{{{
  let pairs = map(a:list, printf('[v:val, %s]', a:expr))
  return map(s:sort(pairs,
  \      'a:a[1] ==# a:b[1] ? 0 : a:a[1] ># a:b[1] ? 1 : -1'), 'v:val[0]')
endfunction"}}}

" Sorts a list with expression to compare each two values.
" a:a and a:b can be used in {expr}.
function! s:sort(list, expr) "{{{
  if type(a:expr) == type(function('function'))
    return sort(a:list, a:expr)
  endif
  let s:expr = a:expr
  return sort(a:list, 's:_compare')
endfunction"}}}

function! s:_compare(a, b)
  return eval(s:expr)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker

