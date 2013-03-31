"=============================================================================
" FILE: config.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" Last Modified: 31 Mar 2013.
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

if !exists('s:neobundles')
  let s:neobundles = {}
  let s:direct_neobundles = {}
  let s:sourced_neobundles = {}
endif

function! neobundle#config#init()
  augroup neobundle
    autocmd!
    autocmd FileType * call neobundle#autoload#filetype()
    autocmd FuncUndefined * call neobundle#autoload#function()
    autocmd InsertEnter * call neobundle#autoload#insert()
    autocmd VimEnter * call s:on_vim_enter()
    autocmd BufCreate
          \ * call neobundle#autoload#explorer(expand('<amatch>'), 'BufCreate')
    autocmd BufEnter
          \ * call neobundle#autoload#explorer(expand('<amatch>'), 'BufEnter')
    autocmd BufWinEnter
          \ * call neobundle#autoload#explorer(expand('<amatch>'), 'BufWinEnter')
  augroup END

  filetype off

  for bundle in values(s:neobundles)
    if bundle.resettable
      " Reset.
      call s:rtp_rm(bundle)

      call remove(s:neobundles, bundle.name)
    endif
  endfor

  " Load direct installed bundles.
  call neobundle#config#load_direct_bundles()
endfunction

function! neobundle#config#get(name)
  return get(s:neobundles, a:name, {})
endfunction

function! neobundle#config#get_neobundles()
  return values(s:neobundles)
endfunction

function! neobundle#config#get_direct_neobundles()
  return values(s:direct_neobundles)
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

  " Call hooks.
  call neobundle#call_hook('on_source', a:bundles)
endfunction

function! neobundle#config#bundle(arg, ...)
  let bundle = s:parse_arg(a:arg)
  let is_parse_only = get(a:000, 0, 0)
  if empty(bundle) || is_parse_only
    return bundle
  endif

  call s:add_bundle(bundle)

  return bundle
endfunction

function! neobundle#config#lazy_bundle(arg)
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  " Update lazy flag.
  let bundle.lazy = 1
  for depend in bundle.depends
    let depend.lazy = bundle.lazy
  endfor

  call s:add_bundle(bundle)

  return bundle
endfunction

function! neobundle#config#fetch_bundle(arg)
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  " Clear runtimepath.
  let bundle.rtp = ''

  call s:add_bundle(bundle)

  return bundle
endfunction

function! neobundle#config#depends_bundle(arg)
  let bundle = s:parse_arg(a:arg)
  if empty(bundle)
    return {}
  endif

  if !has_key(s:neobundles, bundle.name)
    let bundle.overwrite = 0
    let bundle.resettable = 0

    call s:add_bundle(bundle)

    " Install bundle automatically.
    silent call neobundle#installer#install(0, bundle.name)
  endif

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

  if !empty(bundle.external_commands)
    call neobundle#config#check_external_commands(bundle)
  endif

  return bundle
endfunction

function! neobundle#config#source_bundles(bundles)
  if !empty(a:bundles)
    call neobundle#config#source(map(copy(a:bundles),
          \ "type(v:val) == type({}) ? v:val.name : v:val"))
  endif
endfunction

function! neobundle#config#check_not_exists(names, ...)
  " For infinite loop.
  let self = get(a:000, 0, [])

  let _ = map(neobundle#get_not_installed_bundles(a:names), 'v:val.name')
  for bundle in map(filter(copy(a:names),
        \ 'index(self, v:val) < 0 && has_key(s:neobundles, v:val)'),
        \ 's:neobundles[v:val]')
    call add(self, bundle.name)

    if !empty(bundle.depends)
      let _ += neobundle#config#check_not_exists(
            \ map(copy(bundle.depends), 'v:val.name'), self)
    endif
  endfor

  return neobundle#util#uniq(_)
endfunction

function! neobundle#config#source(names, ...)
  let is_force = get(a:000, 0, 1)

  let names = neobundle#util#convert_list(a:names)
  let bundles = empty(names) ?
        \ neobundle#config#get_neobundles() :
        \ neobundle#config#search(names)
  let not_exists = neobundle#config#check_not_exists(names)
  if !empty(not_exists)
    call neobundle#util#print_error(
          \ 'Not installed plugin-names are detected : '. string(not_exists))
  endif

  let rtps = neobundle#util#split_rtp()
  let bundles = filter(bundles,
        \ "!neobundle#config#is_sourced(v:val.name) &&
        \ v:val.rtp != '' && index(rtps, v:val.rtp) < 0")
  if empty(bundles)
    return
  endif

  redir => filetype_out
  silent filetype
  redir END

  redir => filetype_before
  execute 'silent autocmd FileType' &filetype
  redir END

  let reset_ftplugin = 0
  for bundle in bundles
    let bundle.sourced = 1
    let bundle.disabled = 0

    if !get(s:sourced_neobundles, bundle.name, 0)
      " Unmap dummy mappings.
      for [mode, mapping] in get(bundle, 'dummy_mappings', [])
        silent! execute mode.'unmap' mapping
      endfor

      " Delete dummy commands.
      for command in get(bundle, 'dummy_commands', [])
        silent! execute 'delcommand' command
      endfor

      let s:sourced_neobundles[bundle.name] = 1
    endif

    let bundle.dummy_mappings = []
    let bundle.dummy_commands = []

    if has_key(s:neobundles, bundle.name)
      call s:rtp_rm(bundle)
    endif

    call s:rtp_add(bundle)

    if exists('g:loaded_neobundle') || is_force
      " Reload script files.
      for directory in ['ftdetect', 'after/ftdetect', 'plugin', 'after/plugin']
        for file in split(glob(bundle.rtp.'/'.directory.'/**/*.vim'), '\n')
          silent! source `=file`
        endfor
      endfor

      if has_key(bundle, 'augroup') && exists('#'.bundle.augroup)
        execute 'doautocmd' bundle.augroup 'VimEnter'

        if has('gui_running') && &term ==# 'builtin_gui'
          execute 'doautocmd' bundle.augroup 'GUIEnter'
        endif
      endif
    endif

    if !reset_ftplugin
      for filetype in split(&filetype, '\.')
        let base = bundle.rtp . '/' . directory
        for directory in ['ftplugin', 'indent', 'syntax',
              \ 'after/ftplugin', 'after/indent', 'after/syntax']
          if filereadable(base.'/'.filetype.'.vim') ||
                \ (directory =~# 'ftplugin$' &&
                \   isdirectory(base . '/' . filetype) ||
                \   glob(base.'/'.filetype.'_*.vim') != '')
            let reset_ftplugin = 1
            break
          endif
        endfor
      endfor
    endif

    let bundle.resettable = 0
  endfor

  redir => filetype_after
  execute 'silent autocmd FileType' &filetype
  redir END

  if reset_ftplugin
    filetype off

    if filetype_out =~# 'detection:ON'
      silent! filetype on
    endif

    if filetype_out =~# 'plugin:ON'
      silent! filetype plugin on
    endif

    if filetype_out =~# 'indent:ON'
      silent! filetype indent on
    endif

    " Reload filetype plugins.
    let &l:filetype = &l:filetype
  elseif filetype_before !=# filetype_after
    execute 'doautocmd FileType' &filetype
  endif

  if exists('g:loaded_neobundle')
    call neobundle#call_hook('on_source', bundles)
  endif
endfunction

function! neobundle#config#disable(arg)
  let bundle_names = neobundle#config#search(split(a:arg))
  if empty(bundle_names)
    return
  endif

  for bundle in bundle_names
    call s:rtp_rm(bundle)
    let bundle.sourced = 0
    let bundle.disabled = 1
  endfor
endfunction

function! neobundle#config#is_sourced(name)
  return get(neobundle#config#get(a:name), 'sourced', 0)
endfunction

function! neobundle#config#is_installed(name)
  return isdirectory(get(neobundle#config#get(a:name), 'path', ''))
endfunction

function! neobundle#config#rm_bundle(path)
  for bundle in filter(neobundle#config#get_neobundles(),
        \ 'v:val.path ==# a:path')
    call s:rtp_rm(bundle)
    call remove(s:neobundles, bundle.name)
  endfor

  " Delete from s:direct_neobundles.
  for bundle in filter(neobundle#config#get_direct_neobundles(),
        \ 'v:val.path ==# a:path')
    call remove(s:direct_neobundles, bundle.name)
  endfor

  call neobundle#config#save_direct_bundles()
endfunction

function! neobundle#config#get_types()
  if !exists('s:neobundle_types')
    " Load neobundle types.
    let s:neobundle_types = {}
    for define in map(split(globpath(&runtimepath,
          \ 'autoload/neobundle/types/*.vim', 1), '\n'),
          \ "neobundle#types#{fnamemodify(v:val, ':t:r')}#define()")
      for dict in neobundle#util#convert_list(define)
        if !empty(dict) && !has_key(s:neobundle_types, dict.name)
          let s:neobundle_types[dict.name] = dict
        endif
      endfor
      unlet define
    endfor
  endif

  return s:neobundle_types
endfunction

function! neobundle#config#get_types_list()
  let types = neobundle#config#get_types()
  return [types['git']] + values(types)
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
  call filter(values(s:neobundles), 's:rtp_rm(v:val)')
endfunction

function! s:rtp_rm(bundle)
  execute 'set rtp-='.fnameescape(a:bundle.rtp)
  if isdirectory(a:bundle.rtp.'/after')
    execute 'set rtp-='.fnameescape(a:bundle.rtp.'/after')
  endif
endfunction

function! s:rtp_add_bundles(bundles)
  call filter(copy(a:bundles), 's:rtp_add(v:val)')
endfunction

function! s:rtp_add(bundle) abort
  let rtp = a:bundle.rtp
  if isdirectory(rtp)
    if a:bundle.tail_path
      " Join to the tail in runtimepath.
      let rtps = neobundle#util#split_rtp(&runtimepath)
      let n = index(rtps, $VIMRUNTIME)
      let &runtimepath = neobundle#util#join_rtp(
            \ insert(rtps, rtp, n-1), &runtimepath, rtp)
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

  let bundle.orig_name = a:name
  let bundle.orig_opts = a:opts

  let bundle = s:init_bundle(bundle)

  return bundle
endfunction

function! neobundle#config#search(bundle_names, ...)
  " For infinite loop.
  let self = get(a:000, 0, [])

  let _ = []
  for bundle in copy(filter(neobundle#config#get_neobundles(),
        \ 'index(self, v:val.name) < 0 &&
        \       index(a:bundle_names, v:val.name) >= 0'))
    call add(self, bundle.name)

    let _ += neobundle#config#search(
          \ map(copy(bundle.depends), 'v:val.name'), self)
    call add(_, bundle)
  endfor

  return neobundle#util#uniq(_)
endfunction

function! neobundle#config#search_simple(bundle_names)
  return filter(neobundle#config#get_neobundles(),
        \ 'index(a:bundle_names, v:val.name) >= 0')
endfunction

function! neobundle#config#fuzzy_search(bundle_names)
  let bundles = []
  for name in a:bundle_names
    let bundles += filter(neobundle#config#get_neobundles(),
          \ 'stridx(v:val.name, name) >= 0')
  endfor

  let _ = []
  for bundle in bundles
    let _ += neobundle#config#search(
          \ map(copy(bundle.depends), 'v:val.name'))
    call add(_, bundle)
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

if neobundle#util#is_windows()
  function! s:expand_path(path)
    return neobundle#util#substitute_path_separator(
          \ simplify(expand(escape(a:path, '*?{}'), 1)))
  endfunction
else
  function! s:expand_path(path)
    return simplify(expand(escape(a:path, '*?{}'), 1))
  endfunction
endif

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
    sandbox let s:direct_neobundles =
          \ eval(get(readfile(path), 0, '[]'))
    call map(s:direct_neobundles, 's:init_bundle(v:val)')
  endif

  call extend(s:neobundles, s:direct_neobundles)
endfunction

function! neobundle#config#save_direct_bundles()
  call writefile([string(s:direct_neobundles)],
        \ neobundle#get_neobundle_dir() . '/.direct_bundles')
endfunction

function! neobundle#config#check_external_commands(bundle)
  " Environment check.
  let external_commands = a:bundle.external_commands
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

  for command in neobundle#util#convert_list(commands)
    if !executable(command)
      call neobundle#installer#error(
            \ printf('external command : "%s" is not found.', command))
      call neobundle#installer#error(
            \ printf('"%s" needs it.', a:bundle.name))
    endif
  endfor
endfunction

function! neobundle#config#set(name, dict)
  let bundle = neobundle#config#get(a:name)
  if empty(bundle)
    return
  endif

  let bundle = s:init_bundle(extend(bundle, a:dict))
  if bundle.lazy && bundle.sourced &&
        \ !get(s:sourced_neobundles, bundle.name, 0)
    " Remove from runtimepath.
    call s:rtp_rm(bundle)
    let bundle.sourced = 0
  endif

  call s:add_bundle(bundle, 1)
endfunction

function! s:add_bundle(bundle, ...)
  let bundle = a:bundle
  let is_force = get(a:000, 0, 0)

  if bundle.disabled
        \ || (!is_force && !bundle.overwrite &&
        \     has_key(s:neobundles, bundle.name))
        \ || (bundle.gui && !has('gui_running'))
        \ || (bundle.terminal && has('gui_running'))
    return
  endif

  let prev_bundle = get(s:neobundles, bundle.name, {})

  let s:neobundles[bundle.name] = bundle

  " Add depends.
  for depend in a:bundle.depends
    if !has_key(s:neobundles, depend.name)
      call s:add_bundle(depend)
    elseif !depend.lazy
      " Load automatically.
      call neobundle#config#source(depend.name)
    endif
  endfor

  if !bundle.lazy && bundle.rtp != ''
    if bundle.sourced
      call s:rtp_rm(bundle)
    endif

    let bundle.sourced = 1
    call s:rtp_add(bundle)
  elseif bundle.lazy && !neobundle#config#is_sourced(bundle.name)
    let bundle.dummy_commands = []
    for item in neobundle#util#convert_list(
          \ get(bundle.autoload, 'commands', []))
      let command = type(item) == type('') ?
            \ { 'name' : item } : item

      " Define dummy commands.
      silent! execute 'command ' . (get(command, 'complete', '') != '' ?
            \ ('-complete=' . command.complete) : '')
            \ . ' -bang -range -nargs=*' command.name printf(
            \ "call neobundle#autoload#command(%s, %s, <q-args>,
            \  expand('<bang>'), expand('<line1>'), expand('<line2>'))",
            \   string(command.name), string(bundle.name))
      unlet item

      call add(bundle.dummy_commands, command.name)
    endfor

    let bundle.dummy_mappings = []
    for map in neobundle#util#convert_list(
          \ get(bundle.autoload, 'mappings', []))
      if type(map) == type([])
        let [mode, mapping] = [map[0], map[1]]
      else
        let [mode, mapping] = ['nxo', map]
      endif

      " Define dummy mappings.
      for mode in filter(split(mode, '\zs'),
            \ "index(['n', 'v', 'x', 'o', 'i'], v:val) >= 0")
        silent! execute mode.'noremap <unique><silent>' mapping printf(
              \ (mode ==# 'i' ? "\<C-o>:" : ":\<C-u>").
              \   "call neobundle#autoload#mapping(%s, %s, %s)<CR>",
              \   string(mapping), string(bundle.name), string(mode))

        call add(bundle.dummy_mappings, [mode, mapping])
      endfor

      unlet map
    endfor
  endif

  if !is_force && bundle.overwrite &&
        \ !empty(prev_bundle) && prev_bundle.overwrite && bundle !=# prev_bundle
        \ && prev_bundle.resettable && prev_bundle.overwrite
    " Warning.
    call neobundle#util#print_error(
          \ 'Overwrite previous neobundle configuration in ' . bundle.name)
  endif
endfunction

function! s:get_default()
  if !exists('s:default_bundle')
    let s:default_bundle = {
          \ 'uri' : '',
          \ 'tail_path' : g:neobundle#enable_tail_path,
          \ 'script_type' : '',
          \ 'rev' : '',
          \ 'rtp' : '',
          \ 'depends' : [],
          \ 'lazy' : 0,
          \ 'gui' : 0,
          \ 'terminal' : 0,
          \ 'overwrite' : 1,
          \ 'resettable' : 1,
          \ 'stay_same' : 0,
          \ 'hooks' : {},
          \ 'external_commands' : {},
          \ 'autoload' : {},
          \ 'description' : '',
          \ 'dummy_commands' : [],
          \ 'dummy_mappings' : [],
          \ 'sourced' : 0,
          \ 'disabled' : 0,
          \ }
  endif

  let s:default_bundle.base = neobundle#get_neobundle_dir()

  return deepcopy(s:default_bundle)
endfunction

function! s:init_bundle(bundle)
  let bundle = a:bundle
  if !has_key(bundle, 'type')
    call neobundle#installer#error(
          \ printf('Failed parse name "%s" and args %s',
          \   a:bundle.orig_name, string(a:bundle.orig_opts)))
    return {}
  endif

  let bundle = extend(s:get_default(), bundle)

  if !has_key(bundle, 'name')
    let bundle.name =
          \ substitute(split(bundle.orig_name, '/')[-1], '\.git\s*$','','i')
  endif
  if !has_key(bundle, 'directory')
    let bundle.directory = bundle.name
  endif

  let bundle.base = s:expand_path(bundle.base)
  if bundle.rev != ''
    let bundle.directory .= '_' . substitute(bundle.rev,
          \ '[^[:alnum:]_.-]', '', 'g')
  endif

  let bundle.path = s:expand_path(bundle.base.'/'.bundle.directory)

  let rtp = bundle.rtp
  " Check relative path.
  let bundle.rtp = (rtp =~ '^\%(/\|\~\|\a\+:\)') ?
        \ rtp : (bundle.path.'/'.rtp)
  let bundle.rtp = s:expand_path(bundle.rtp)
  if bundle.rtp =~ '[/\\]$'
    " Chomp.
    let bundle.rtp = substitute(bundle.rtp, '[/\\]\+$', '', '')
  endif
  if bundle.name ==# 'neobundle.vim'
    " Do not add runtimepath.
    let bundle.rtp = ''
  endif

  if bundle.script_type != ''
    " Add script_type.
    let bundle.path .= '/' . bundle.script_type
  endif

  if !has_key(bundle.autoload, 'function_prefix')
        \ && isdirectory(bundle.rtp . '/autoload')
    let bundle.autoload.function_prefix =
          \ neobundle#config#_parse_function_prefix(bundle.name)
  endif

  " Parse depends.
  let _ = []
  for depend in neobundle#util#convert_list(bundle.depends)
    if type(depend) == type('')
      let depend = string(depend)
    endif
    let depend_bundle = neobundle#config#bundle(depend, 1)
    let depend_bundle.lazy = bundle.lazy
    let depend_bundle.overwrite = 0
    call add(_, depend_bundle)

    unlet depend
  endfor
  let bundle.depends = _

  if neobundle#config#is_sourced(bundle.name)
    let bundle.sourced = 1
  endif

  return bundle
endfunction

function! neobundle#config#_parse_function_prefix(name)
  let function_prefix = tolower(fnamemodify(a:name, ':r'))
  let function_prefix = substitute(function_prefix,
        \'^vim-', '','g')
  let function_prefix = substitute(function_prefix,
        \'^unite-', 'unite#sources#','g')
  let function_prefix = substitute(function_prefix,
        \'-', '_', 'g')
  return function_prefix
endfunction

function! neobundle#config#tsort(bundles)
  let sorted = []
  let mark = {}
  for target in a:bundles
    call s:tsort_impl(target, a:bundles, mark, sorted)
  endfor

  return sorted
endfunction

function! s:tsort_impl(target, bundles, mark, sorted)
  if has_key(a:mark, a:target.name)
    return
  endif

  let a:mark[a:target.name] = 1
  for depend in get(a:target, 'depends', [])
    call s:tsort_impl(get(s:neobundles, depend.name, depend),
          \ a:bundles, a:mark, a:sorted)
  endfor

  call add(a:sorted, a:target)
endfunction

function! s:on_vim_enter()
  " Call hooks.
  call neobundle#call_hook('on_source')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
