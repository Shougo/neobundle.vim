"=============================================================================
" FILE: config.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 02 Dec 2012.
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
" Version: 0.1, for Vim 7.2
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

if !exists('s:neobundles')
  let s:neobundles = {}
  let s:loaded_neobundles = {}
  let s:direct_neobundles = {}
  let s:disabled_neobundles = {}
endif

function! neobundle#config#init()
  call s:rtp_rm_all_bundles()

  for bundle in values(s:neobundles)
    if bundle.resettable
      " Reset.
      call remove(s:neobundles, bundle.path)
      if neobundle#config#is_sourced(bundle.name)
        call remove(s:loaded_neobundles, bundle.name)
      endif
    endif
  endfor

  " Load direct installed bundles.
  call neobundle#config#load_direct_bundles()
endfunction

function! neobundle#config#get_neobundles()
  return sort(values(s:neobundles), 's:compare_names')
endfunction

function! s:compare_names(a, b)
  return (a:a.name >? a:b.name) ? 1 : -1
endfunction

function! neobundle#config#reload(bundles)
  if empty(a:bundles)
    return
  endif

  call s:rtp_add_bundles(a:bundles)

  " Delete old g:loaded_xxx variables.
  for var_name in keys(g:)
    if var_name =~ '^loaded_'
      execute 'unlet!' var_name
    endif
  endfor

  silent! runtime! ftdetect/**/*.vim
  silent! runtime! after/ftdetect/**/*.vim
  silent! runtime! plugin/**/*.vim
  silent! runtime! after/plugin/**/*.vim

  " Reload autoload scripts.
  let scripts = []
  for line in split(s:redir('scriptnames'), "\n")
    let name = matchstr(line, '^\s*\d\+:\s\+\zs.\+\ze\s*$')
    if name != '' && name =~ '/autoload/'
          \ && name !~ '/unite.vim/\|/neobundle.vim/'
      call add(scripts, s:unify_path(name))
    endif
  endfor

  for script in scripts
    for bundle in filter(copy(a:bundles),
          \ 'stridx(script, v:val.path) >= 0')
      silent! execute source `=script`
    endfor
  endfor
endfunction

function! neobundle#config#bundle(arg, ...)
  let bundle = s:parse_arg(a:arg)
  let is_parse_only = get(a:000, 0, 0)
  if empty(bundle) || is_parse_only
    return bundle
  endif

  let path = bundle.path
  if has_key(s:neobundles, path)
    call s:rtp_rm(bundle)
  endif

  let s:neobundles[path] = bundle
  if !get(s:disabled_neobundles, bundle.name, 0)
    let s:loaded_neobundles[bundle.name] = 1
    call s:rtp_add(bundle)
    call s:load_depends(bundle)
  endif

  return bundle
endfunction

function! neobundle#config#lazy_bundle(arg)
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  let path = bundle.path

  let s:neobundles[path] = bundle
  return bundle
endfunction

function! neobundle#config#depends_bundle(arg)
  let bundle = s:parse_arg(a:arg)

  if empty(bundle) || has_key(s:neobundles, bundle.path)
    " Ignore.
    return {}
  endif

  let bundle = neobundle#config#bundle(a:arg)
  let bundle.resettable = 0
  let s:loaded_neobundles[bundle.name] = 0

  " Install bundle automatically.
  silent call neobundle#installer#install(0, bundle.name)

  " Load scripts.
  call neobundle#config#source(bundle.name)

  return bundle
endfunction

function! neobundle#config#direct_bundle(arg)
  let bundle = neobundle#config#bundle(a:arg)

  if empty(bundle)
    return {}
  endif

  let path = bundle.path

  let s:direct_neobundles[path] = bundle
  call neobundle#config#save_direct_bundles()

  " Direct install.
  call neobundle#installer#install(0, bundle.name)

  return bundle
endfunction

function! s:parse_arg(arg)
  let arg = type(a:arg) == type([]) ?
   \ string(a:arg) : '[' . a:arg . ']'
  sandbox let args = eval(arg)
  if empty(args)
    return {}
  endif

  let bundle = neobundle#config#init_bundle(
        \ args[0], args[1:])
  if empty(bundle)
    return {}
  endif

  let bundle.orig_arg = a:arg

  call neobundle#config#check_external_commands(bundle)

  return bundle
endfunction

function! neobundle#config#source(...)
  let bundles = empty(a:000) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(a:000)
  let bundles = filter(bundles,
        \ '!neobundle#config#is_sourced(v:val.name)')
  if empty(bundles)
    return
  endif

  redir => filetype_out
    silent filetype
  redir END

  filetype off

  for bundle in bundles
    if has_key(s:neobundles, bundle.path)
      call s:rtp_rm(bundle)
    endif
    call s:rtp_add(bundle)

    call s:load_depends(bundle)

    for directory in
          \ ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin']
      for file in split(glob(bundle.rtp.'/'.directory.'/**/*.vim'), '\n')
        try
          source `=file`
        catch /^Vim\%((\a\+)\)\?:E127/
        endtry
      endfor
    endfor

    if has_key(bundle, 'augroup') && exists('#'.bundle.augroup)
      execute 'doautocmd' bundle.augroup 'VimEnter'

      if has('gui_running')
        execute 'doautocmd' bundle.augroup 'GUIEnter'
      endif
    endif

    let s:loaded_neobundles[bundle.name] = 1
    let s:disabled_neobundles[bundle.name] = 0
  endfor

  if filetype_out =~# 'detection:ON'
    silent! filetype on

    if filetype_out =~# 'plugin:ON'
      silent! filetype plugin on
    endif
    if filetype_out =~# 'indent:ON'
      silent! filetype indent on
    endif
  endif

  " Reload filetype plugins.
  let &l:filetype = &l:filetype
endfunction

function! neobundle#config#disable(arg)
  let bundle_names = split(a:arg)

  for bundle in neobundle#config#search(bundle_names)
    call s:rtp_rm(bundle)
    if has_key(s:loaded_neobundles, bundle.name)
      call remove(s:loaded_neobundles, bundle.name)
    endif

    let s:disabled_neobundles[bundle.name] = 1
  endfor
endfunction

function! neobundle#config#is_sourced(name)
  return get(s:loaded_neobundles, a:name, 0)
endfunction

function! neobundle#config#rm_bundle(path)
  if has_key(s:neobundles, a:path)
    call s:rtp_rm(s:neobundles[a:path])
    call remove(s:neobundles, a:path)
  endif

  " Delete from s:direct_neobundles.
  if has_key(s:direct_neobundles, a:path)
    call remove(s:direct_neobundles, a:path)
  endif

  call neobundle#config#save_direct_bundles()
endfunction

function! neobundle#config#get_types()
  if !exists('s:neobundle_types')
    " Load neobundle types.
    let s:neobundle_types = {}
    for define in map(split(globpath(&runtimepath,
          \ 'autoload/neobundle/types/*.vim', 1), '\n'),
          \ "neobundle#types#{fnamemodify(v:val, ':t:r')}#define()")
      for dict in (type(define) == type([]) ? define : [define])
        if !empty(dict) && !has_key(s:neobundle_types, dict.name)
          let s:neobundle_types[dict.name] = dict
        endif
      endfor
      unlet define
    endfor
  endif

  return s:neobundle_types
endfunction

function! neobundle#config#parse_path(path, ...)
  let opts = get(a:000, 0, {})
  let site = get(opts, 'site', g:neobundle#default_site)
  let path = a:path

  if path !~ ':'
    " Add default site.
    let path = site . ':' . path
  endif

  for type in values(neobundle#config#get_types())
    let detect = type.detect(path, opts)
    if !empty(detect)
      return detect
    endif
  endfor

  return {}
endfunction

function! s:rtp_rm_all_bundles()
  call filter(filter(values(s:neobundles),
        \ "v:val.name !=# 'neobundle.vim'"), 's:rtp_rm(v:val)')
endfunction

function! s:rtp_rm(bundle)
  let dir = a:bundle.rtp
  execute 'set rtp-='.fnameescape(neobundle#util#expand(dir))
  execute 'set rtp-='.fnameescape(neobundle#util#expand(dir.'/after'))
endfunction

function! s:rtp_add_bundles(bundles)
  call filter(copy(a:bundles), 's:rtp_add(v:val)')
endfunction

function! s:rtp_add(bundle) abort
  let dir = a:bundle.rtp
  let rtp = neobundle#util#expand(dir)
  if isdirectory(rtp)
    if a:bundle.tail_path
      " Join to the tail in runtimepath.
      let rtps = neobundle#util#split_rtp(&runtimepath)
      let n = index(rtps, $VIMRUNTIME)
      let &runtimepath = neobundle#util#join_rtp(insert(rtps, rtp, n))
    else
      execute 'set rtp^='.fnameescape(rtp)
    endif
  endif
  if isdirectory(rtp.'/after')
    execute 'set rtp+='.fnameescape(rtp.'/after')
  endif
endfunction

function! neobundle#config#init_bundle(name, opts)
  let path = substitute(a:name, "['".'"]\+', '', 'g')
  let opts = s:parse_options(a:opts)
  let bundle = extend(neobundle#config#parse_path(
        \ path, opts), opts)
  if !has_key(bundle, 'uri')
    let bundle.uri = path
  endif
  if !has_key(bundle, 'name')
    let bundle.name =
          \ substitute(split(path, '/')[-1], '\.git\s*$','','i')
  endif
  if !has_key(bundle, 'tail_path')
    let bundle.tail_path = g:neobundle#enable_tail_path
  endif
  if !has_key(bundle, 'script_type')
    let bundle.script_type = ''
  endif
  if !has_key(bundle, 'rev')
    let bundle.rev = ''
  endif

  if !has_key(bundle, 'type')
    call neobundle#installer#error(
          \ printf('Failed parse name "%s" and args %s',
          \   a:name, string(a:opts)))
    return {}
  endif

  let bundle.base = s:expand_path(get(bundle, 'base',
        \ neobundle#get_neobundle_dir()))
  let bundle.path = s:expand_path(bundle.base.'/'.
        \ get(bundle, 'directory', bundle.name))

  let rtp = get(bundle, 'rtp', '')
  " Check relative path.
  let bundle.rtp = (rtp =~ '^\%(/\|\~\|\a\+:\)') ?
        \ rtp : (bundle.path.'/'.rtp)
  let bundle.rtp = s:expand_path(bundle.rtp)
  if bundle.rtp =~ '[/\\]$'
    " Chomp.
    let bundle.rtp = substitute(bundle.rtp, '[/\\]\+$', '', '')
  endif

  let depends = get(bundle, 'depends', [])
  let bundle.depends = type(depends) == type('') ?
        \ [depends] : depends

  let bundle.orig_name = a:name
  let bundle.orig_opts = a:opts
  let bundle.resettable = 1

  return bundle
endfunction

function! neobundle#config#search(bundle_names)
  let _ = filter(neobundle#config#get_neobundles(),
        \ 'index(a:bundle_names, v:val.name) >= 0')

  for bundle in copy(_)
    for depend in bundle.depends
      if type(depend) == type('')
        let depend = string(depend)
      endif
      call add(_, neobundle#config#bundle(depend, 1))
    endfor
  endfor

  return neobundle#util#uniq(_)
endfunction

function! neobundle#config#fuzzy_search(bundle_names)
  let _ = []
  for bundle in neobundle#config#get_neobundles()
    for name in a:bundle_names
      if stridx(bundle.name, name) >= 0
        call add(_, bundle)
        break
      endif
    endfor
  endfor

  for bundle in copy(_)
    for depend in bundle.depends
      if type(depend) == type('')
        let depend = string(depend)
      endif
      call add(_, neobundle#config#bundle(depend, 1))
    endfor
  endfor

  return neobundle#util#uniq(_)
endfunction

function! s:parse_options(opts)
  if empty(a:opts)
    return get(g:neobundle#default_options, '_', {})
  endif

  if len(a:opts) == 3
    " rev, default, options
    let [rev, default, options] = a:opts
  elseif len(a:opts) == 2 && type(a:opts[-1]) == type('')
    " rev, default
    let [rev, default, options] = a:opts + [{}]
  elseif len(a:opts) == 2 && type(a:opts[-1]) == type({})
    " rev, options
    let [rev, default, options] = [a:opts[0], '', a:opts[1]]
  elseif len(a:opts) == 1 && type(a:opts[-1]) == type('')
    " rev
    let [rev, default, options] = [a:opts[0], '', {}]
  elseif len(a:opts) == 1 && type(a:opts[-1]) == type({})
    " options
    let [rev, default, options] = ['', '', a:opts[0]]
  else
    call neobundle#installer#error(
          \ printf('Invalid option : "%s".', string(a:opts)))
    return {}
  endif

  if rev != ''
    let options.rev = rev
  endif

  if !has_key(options, 'default')
    let options.default = (default == '') ?  '_' : default
  endif

  " Set default options.
  if has_key(g:neobundle#default_options, options.default)
    call extend(options,
          \ g:neobundle#default_options[options.default], 'keep')
  endif

  return options
endfunction

function! s:expand_path(path)
  return neobundle#util#substitute_path_separator(
        \ simplify(neobundle#util#expand(a:path)))
endfunction

function! s:redir(cmd)
  redir => res
  silent! execute a:cmd
  redir END
  return res
endfunction

function! s:unify_path(path)
  return fnamemodify(resolve(a:path), ':p:gs?\\\+?/?')
endfunction

function! neobundle#config#load_direct_bundles()
  let path = neobundle#get_neobundle_dir() . '/.direct_bundles'

  if !filereadable(path)
    let s:direct_neobundles = {}
  else
    sandbox let s:direct_neobundles = eval(get(readfile(path), 0, '[]'))
  endif

  call extend(s:neobundles, s:direct_neobundles)
endfunction

function! neobundle#config#save_direct_bundles()
  call writefile([string(s:direct_neobundles)],
        \ neobundle#get_neobundle_dir() . '/.direct_bundles')
endfunction

function! neobundle#config#check_external_commands(bundle)
  " Environment check.
  let external_commands = get(a:bundle, 'external_commands', {})
  if type(external_commands) == type([])
        \ || type(external_commands) == type('')
    let commands = external_commands
  elseif neobundle#util#is_windows() && has_key(external_commands, 'windows')
    let commands = external_commands.windows
  elseif neobundle#util#is_mac() && has_key(external_commands, 'mac')
    let commands = external_commands.mac
  elseif neobundle#util#is_cygwin() && has_key(external_commands, 'cygwin')
    let commands = external_commands.cygwin
  elseif !neobundle#util#is_windows() && has_key(external_commands, 'unix')
    let commands = external_commands.unix
  elseif has_key(external_commands, 'others')
    let commands = external_commands.others
  else
    " Invalid.
    return
  endif

  for command in (type(commands) == type([]) ?
        \ commands : [commands])
    if !executable(command)
      call neobundle#installer#error(
            \ printf('external command : "%s" is not found.', command))
      call neobundle#installer#error(
            \ printf('"%s" needs it.', a:bundle.name))
    endif
  endfor
endfunction

function! s:load_depends(bundle)
  for depend in a:bundle.depends
    if type(depend) == type('')
      let depend = string(depend)
    endif

    " Parse check.
    let depend_bundle = neobundle#config#bundle(depend, 1)
    if !has_key(s:neobundles, depend_bundle.path)
      call neobundle#config#bundle(depend)
    endif

    unlet depend
  endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

