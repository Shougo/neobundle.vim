let s:suite = themis#suite('parser')
let s:assert = themis#helper('assert')

let g:neobundle#types#git#default_protocol = 'git'
let g:neobundle#types#hg#default_protocol = 'https'
let g:neobundle#enable_name_conversion = 0

function! s:suite.github_git_repos()
  call s:assert.equals(neobundle#parser#path(
        \ 'Shougo/neocomplcache-clang.git'),
        \ {'type' : 'git', 'uri' :
        \   g:neobundle#types#git#default_protocol .
        \  '://github.com/Shougo/neocomplcache-clang.git',
        \  'name' : 'neocomplcache-clang'})
  call s:assert.equals(neobundle#parser#path('Shougo/vimshell'),
        \ {'type' : 'git', 'uri' :
        \   g:neobundle#types#git#default_protocol .
        \  '://github.com/Shougo/vimshell.git',
        \  'name' : 'vimshell'})
  call s:assert.equals(neobundle#parser#path('rails.vim'),
        \ {'type' : 'git', 'uri' :
        \ g:neobundle#types#git#default_protocol .
        \ '://github.com/vim-scripts/rails.vim.git',
        \  'name' : 'rails.vim'})
  call s:assert.equals(neobundle#parser#path(
        \ 'git://git.wincent.com/command-t.git'),
        \ {'type' : 'git', 'uri' :
        \  'git://git.wincent.com/command-t.git',
        \  'name' : 'command-t'})
  call s:assert.equals(neobundle#parser#path('vim-scripts/ragtag.vim'),
        \ {'type' : 'git', 'uri' :
        \ g:neobundle#types#git#default_protocol .
        \ '://github.com/vim-scripts/ragtag.vim.git',
        \  'name' : 'ragtag.vim'})
  call s:assert.equals(neobundle#parser#path(
        \ 'https://github.com/vim-scripts/vim-game-of-life'),
        \ {'type' : 'git', 'uri' :
        \ 'https://github.com/vim-scripts/vim-game-of-life.git',
        \  'name' : 'vim-game-of-life'})
  call s:assert.equals(neobundle#parser#path(
        \ 'git@github.com:gmarik/ingretu.git'),
        \ {'type' : 'git', 'uri' :
        \ 'git@github.com:gmarik/ingretu.git',
        \  'name' : 'ingretu'})
  call s:assert.equals(neobundle#parser#path(
        \ 'gh:gmarik/snipmate.vim.git'),
        \ {'type' : 'git', 'uri' :
        \ g:neobundle#types#git#default_protocol .
        \ '://github.com/gmarik/snipmate.vim.git',
        \  'name' : 'snipmate.vim'})
  call s:assert.equals(neobundle#parser#path(
        \ 'github:mattn/gist-vim.git'),
        \ {'type' : 'git', 'uri' :
        \ g:neobundle#types#git#default_protocol .
        \ '://github.com/mattn/gist-vim.git',
        \  'name' : 'gist-vim'})
  call s:assert.equals(neobundle#parser#path(
        \ 'git@github.com:Shougo/neocomplcache.git'),
        \ {'type' : 'git', 'uri' :
        \ 'git@github.com:Shougo/neocomplcache.git',
        \  'name' : 'neocomplcache'})
  call s:assert.equals(neobundle#parser#path(
        \ 'git://git.wincent.com/command-t.git'),
        \ {'type' : 'git', 'uri' :
        \  'git://git.wincent.com/command-t.git',
        \  'name' : 'command-t'})
  call s:assert.equals(neobundle#parser#path(
        \ 'https://github.com/Shougo/neocomplcache/'),
        \ {'type' : 'git', 'uri' :
        \ 'https://github.com/Shougo/neocomplcache.git',
        \  'name' : 'neocomplcache'})
endfunction

function! s:suite.svn_repos()
  call s:assert.equals(neobundle#parser#path(
        \ 'http://svn.macports.org/repository/macports/contrib/mpvim/'),
        \ {'type' : 'svn', 'uri' :
        \  'http://svn.macports.org/repository/macports/contrib/mpvim',
        \  'name' : 'mpvim'})
  call s:assert.equals(neobundle#parser#path(
        \ 'thinca/vim-localrc', {'type' : 'svn'}),
        \ {'type' : 'svn', 'uri' :
        \  'https://github.com/thinca/vim-localrc/trunk',
        \  'name' : 'vim-localrc'})
endfunction

function! s:suite.hg_repos()
  call s:assert.equals(neobundle#parser#path(
        \ 'https://bitbucket.org/ns9tks/vim-fuzzyfinder'),
        \ {'type' : 'hg', 'uri' :
        \  'https://bitbucket.org/ns9tks/vim-fuzzyfinder',
        \  'name' : 'vim-fuzzyfinder'})
  call s:assert.equals(neobundle#parser#path(
        \ 'bitbucket://bitbucket.org/ns9tks/vim-fuzzyfinder'),
        \ {'type' : 'hg', 'uri' :
        \  g:neobundle#types#hg#default_protocol.
        \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
        \  'name' : 'vim-fuzzyfinder'})
  call s:assert.equals(neobundle#parser#path(
        \ 'bitbucket:ns9tks/vim-fuzzyfinder'),
        \ {'type' : 'hg', 'uri' :
        \  g:neobundle#types#hg#default_protocol.
        \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
        \  'name' : 'vim-fuzzyfinder'})
  call s:assert.equals(neobundle#parser#path(
        \ 'ns9tks/vim-fuzzyfinder', {'site': 'bitbucket'}),
        \ {'type' : 'hg', 'uri' :
        \  g:neobundle#types#hg#default_protocol.
        \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
        \  'name' : 'vim-fuzzyfinder'})

  let bundle = neobundle#parser#_init_bundle(
        \ 'git://github.com/Shougo/neobundle.vim.git',
        \ [{ 'type' : 'hg'}])
  call s:assert.equals(bundle.name, 'neobundle.vim')
  call s:assert.equals(bundle.type, 'hg')
  call s:assert.equals(bundle.uri,  'git://github.com/Shougo/neobundle.vim.git')
endfunction

function! s:suite.gitbucket_git_repos()
  call s:assert.equals(neobundle#parser#path(
        \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git'),
        \ {'type' : 'git', 'uri' :
        \  'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
        \  'name' : 'vim-qt-syntax'})
  call s:assert.equals(neobundle#parser#path(
        \ 'git://bitbucket.org/kh3phr3n/vim-qt-syntax.git'),
        \ {'type' : 'git', 'uri' :
        \  'git://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
        \  'name' : 'vim-qt-syntax'})
  call s:assert.equals(neobundle#parser#path(
        \ 'bitbucket:kh3phr3n/vim-qt-syntax.git'),
        \ {'type' : 'git', 'uri' :
        \  g:neobundle#types#git#default_protocol.
        \  '://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
        \  'name' : 'vim-qt-syntax'})
endfunction

function! s:suite.raw_repos()
  let bundle = neobundle#parser#_init_bundle(
        \ 'https://raw.github.com/m2ym/rsense/master/etc/rsense.vim',
        \ [{ 'script_type' : 'plugin'}])
  call s:assert.equals(bundle.name, 'rsense.vim')
  call s:assert.equals(bundle.type, 'raw')
  call s:assert.equals(bundle.uri,
        \ 'https://raw.github.com/m2ym/rsense/master/etc/rsense.vim')
endfunction

function! s:suite.default_options()
  let g:default_options_save = g:neobundle#default_options
  let g:neobundle#default_options =
        \ { 'rev' : {'type__update_style' : 'current'},
        \   '_' : {'type' : 'hg'} }

  let bundle = neobundle#parser#_init_bundle(
        \ 'Shougo/neocomplcache', ['', 'rev', {}])
  call s:assert.equals(bundle.type__update_style, 'current')

  let bundle2 = neobundle#parser#_init_bundle(
        \ 'Shougo/neocomplcache', [])
  call s:assert.equals(bundle2.type, 'hg')

  let g:neobundle#default_options = g:default_options_save
endfunction

function! s:suite.ssh_protocol()
  let bundle = neobundle#parser#_init_bundle(
        \ 'accountname/reponame', [{
        \ 'site' : 'github', 'type' : 'git', 'type__protocol' : 'ssh' }])
  call s:assert.equals(bundle.uri,
        \ 'git@github.com:accountname/reponame.git')

  let bundle = neobundle#parser#_init_bundle(
        \ 'accountname/reponame', [{
        \ 'site' : 'bitbucket', 'type' : 'hg', 'type__protocol' : 'ssh' }])
  call s:assert.equals(bundle.uri,
        \ 'ssh://hg@bitbucket.org/accountname/reponame')

  let bundle = neobundle#parser#_init_bundle(
        \ 'accountname/reponame.git', [{
        \ 'site' : 'bitbucket', 'type' : 'git', 'type__protocol' : 'ssh' }])
  call s:assert.equals(bundle.uri,
        \ 'git@bitbucket.org:accountname/reponame.git')
endfunction

function! s:suite.fetch_plugins()
  let bundle = neobundle#parser#fetch(
        \ string('accountname/reponame.git'))
  call s:assert.equals(bundle.rtp, '')
endfunction

function! s:suite.parse_directory()
  let bundle = neobundle#parser#_init_bundle(
        \ 'Shougo/neocomplcache', [])
  call s:assert.equals(bundle.directory, 'neocomplcache')

  let bundle = neobundle#parser#_init_bundle(
        \ 'Shougo/neocomplcache', ['ver.3'])
  call s:assert.equals(bundle.directory, 'neocomplcache_ver_3')
endfunction

function! s:suite.parse_function_prefix()
  call s:assert.equals(neobundle#parser#_function_prefix(
        \ 'neobundle.vim'), 'neobundle')

  call s:assert.equals(neobundle#parser#_function_prefix(
        \ 'unite-tag'), 'unite#sources#tag')

  call s:assert.equals(neobundle#parser#_function_prefix(
        \ 'TweetVim'), 'tweetvim')

  call s:assert.equals(neobundle#parser#_function_prefix(
        \ 'vim-vcs'), 'vcs')

  call s:assert.equals(neobundle#parser#_function_prefix(
        \ 'gist-vim'), 'gist')
endfunction

function! s:suite.name_conversion()
  let g:neobundle#enable_name_conversion = 1

  let bundle = neobundle#parser#_init_bundle(
        \ 'git://github.com/Shougo/neobundle.vim.git',
        \ [{ 'type' : 'hg'}])
  call s:assert.equals(bundle.name, 'neobundle')

  let bundle = neobundle#parser#_init_bundle(
        \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
        \ [{ 'type' : 'hg'}])
  call s:assert.equals(bundle.name, 'qt-syntax')

  let bundle = neobundle#parser#_init_bundle(
        \ 'https://bitbucket.org/kh3phr3n/qt-syntax-vim.git',
        \ [{ 'type' : 'hg'}])
  call s:assert.equals(bundle.name, 'qt-syntax')

  let bundle = neobundle#parser#_init_bundle(
        \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
        \ [{ 'name' : 'vim-qt-syntax'}])
  call s:assert.equals(bundle.name, 'vim-qt-syntax')

  let g:neobundle#enable_name_conversion = 0
endfunction

" vim:foldmethod=marker:fen:
