scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context types
  let g:neobundle#types#git#default_protocol = 'git'
  let g:neobundle#types#hg#default_protocol = 'https'
  let g:neobundle#enable_name_conversion = 0

  It parses github git repos
    ShouldEqual neobundle#parser#path(
          \ 'Shougo/neocomplcache-clang.git'),
          \ {'type' : 'git', 'uri' :
          \   g:neobundle#types#git#default_protocol .
          \  '://github.com/Shougo/neocomplcache-clang.git',
          \  'name' : 'neocomplcache-clang'}
    ShouldEqual neobundle#parser#path('Shougo/vimshell'),
          \ {'type' : 'git', 'uri' :
          \   g:neobundle#types#git#default_protocol .
          \  '://github.com/Shougo/vimshell.git',
          \  'name' : 'vimshell'}
    ShouldEqual neobundle#parser#path('rails.vim'),
          \ {'type' : 'git', 'uri' :
          \ g:neobundle#types#git#default_protocol .
          \ '://github.com/vim-scripts/rails.vim.git',
          \  'name' : 'rails.vim'}
    ShouldEqual neobundle#parser#path(
          \ 'git://git.wincent.com/command-t.git'),
          \ {'type' : 'git', 'uri' :
          \  'git://git.wincent.com/command-t.git',
          \  'name' : 'command-t'}
    ShouldEqual neobundle#parser#path('vim-scripts/ragtag.vim'),
          \ {'type' : 'git', 'uri' :
          \ g:neobundle#types#git#default_protocol .
          \ '://github.com/vim-scripts/ragtag.vim.git',
          \  'name' : 'ragtag.vim'}
    ShouldEqual neobundle#parser#path(
          \ 'https://github.com/vim-scripts/vim-game-of-life'),
          \ {'type' : 'git', 'uri' :
          \ 'https://github.com/vim-scripts/vim-game-of-life.git',
          \  'name' : 'vim-game-of-life'}
    ShouldEqual neobundle#parser#path(
          \ 'git@github.com:gmarik/ingretu.git'),
          \ {'type' : 'git', 'uri' :
          \ 'git@github.com:gmarik/ingretu.git',
          \  'name' : 'ingretu'}
    ShouldEqual neobundle#parser#path(
          \ 'gh:gmarik/snipmate.vim.git'),
          \ {'type' : 'git', 'uri' :
          \ g:neobundle#types#git#default_protocol .
          \ '://github.com/gmarik/snipmate.vim.git',
          \  'name' : 'snipmate.vim'}
    ShouldEqual neobundle#parser#path(
          \ 'github:mattn/gist-vim.git'),
          \ {'type' : 'git', 'uri' :
          \ g:neobundle#types#git#default_protocol .
          \ '://github.com/mattn/gist-vim.git',
          \  'name' : 'gist-vim'}
    ShouldEqual neobundle#parser#path(
          \ 'git@github.com:Shougo/neocomplcache.git'),
          \ {'type' : 'git', 'uri' :
          \ 'git@github.com:Shougo/neocomplcache.git',
          \  'name' : 'neocomplcache'}
    ShouldEqual neobundle#parser#path(
          \ 'git://git.wincent.com/command-t.git'),
          \ {'type' : 'git', 'uri' :
          \  'git://git.wincent.com/command-t.git',
          \  'name' : 'command-t'}
    ShouldEqual neobundle#parser#path(
          \ 'https://github.com/Shougo/neocomplcache/'),
          \ {'type' : 'git', 'uri' :
          \ 'https://github.com/Shougo/neocomplcache.git',
          \  'name' : 'neocomplcache'}
  End

  It parse svn repos
    ShouldEqual neobundle#parser#path(
          \ 'http://svn.macports.org/repository/macports/contrib/mpvim/'),
          \ {'type' : 'svn', 'uri' :
          \  'http://svn.macports.org/repository/macports/contrib/mpvim',
          \  'name' : 'mpvim'}
    ShouldEqual neobundle#parser#path(
          \ 'thinca/vim-localrc', {'type' : 'svn'}),
          \ {'type' : 'svn', 'uri' :
          \  'https://github.com/thinca/vim-localrc/trunk',
          \  'name' : 'vim-localrc'}
  End

  It parses bitbucket hg repos
    ShouldEqual neobundle#parser#path(
          \ 'https://bitbucket.org/ns9tks/vim-fuzzyfinder'),
          \ {'type' : 'hg', 'uri' :
          \  'https://bitbucket.org/ns9tks/vim-fuzzyfinder',
          \  'name' : 'vim-fuzzyfinder'}
    ShouldEqual neobundle#parser#path(
          \ 'bitbucket://bitbucket.org/ns9tks/vim-fuzzyfinder'),
          \ {'type' : 'hg', 'uri' :
          \  g:neobundle#types#hg#default_protocol.
          \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
          \  'name' : 'vim-fuzzyfinder'}
    ShouldEqual neobundle#parser#path(
          \ 'bitbucket:ns9tks/vim-fuzzyfinder'),
          \ {'type' : 'hg', 'uri' :
          \  g:neobundle#types#hg#default_protocol.
          \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
          \  'name' : 'vim-fuzzyfinder'}
    ShouldEqual neobundle#parser#path(
          \ 'ns9tks/vim-fuzzyfinder', {'site': 'bitbucket'}),
          \ {'type' : 'hg', 'uri' :
          \  g:neobundle#types#hg#default_protocol.
          \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
          \  'name' : 'vim-fuzzyfinder'}

    let bundle = neobundle#parser#_init_bundle(
          \ 'git://github.com/Shougo/neobundle.vim.git',
          \ [{ 'type' : 'hg'}])
    ShouldEqual bundle.name, 'neobundle.vim'
    ShouldEqual bundle.type, 'hg'
    ShouldEqual bundle.uri,  'git://github.com/Shougo/neobundle.vim.git'
  End

  It parses bitbucket git repos
    ShouldEqual neobundle#parser#path(
          \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git'),
          \ {'type' : 'git', 'uri' :
          \  'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
          \  'name' : 'vim-qt-syntax'}
    ShouldEqual neobundle#parser#path(
          \ 'git://bitbucket.org/kh3phr3n/vim-qt-syntax.git'),
          \ {'type' : 'git', 'uri' :
          \  'git://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
          \  'name' : 'vim-qt-syntax'}
    ShouldEqual neobundle#parser#path(
          \ 'bitbucket:kh3phr3n/vim-qt-syntax.git'),
          \ {'type' : 'git', 'uri' :
          \  g:neobundle#types#git#default_protocol.
          \  '://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
          \  'name' : 'vim-qt-syntax'}
  End

  It parses raw repos
    let bundle = neobundle#parser#_init_bundle(
          \ 'https://raw.github.com/m2ym/rsense/master/etc/rsense.vim',
          \ [{ 'script_type' : 'plugin'}])
    ShouldEqual bundle.name, 'rsense.vim'
    ShouldEqual bundle.type, 'raw'
    ShouldEqual bundle.uri,
          \ 'https://raw.github.com/m2ym/rsense/master/etc/rsense.vim'
  End

  It parses default options.
    let default_options_save = g:neobundle#default_options
    let g:neobundle#default_options =
          \ { 'rev' : {'type__update_style' : 'current'},
          \   '_' : {'type' : 'hg'} }

    let bundle = neobundle#parser#_init_bundle(
          \ 'Shougo/neocomplcache', ['', 'rev', {}])
    ShouldEqual bundle.type__update_style, 'current'

    let bundle2 = neobundle#parser#_init_bundle(
          \ 'Shougo/neocomplcache', [])
    ShouldEqual bundle2.type, 'hg'

    let g:neobundle#default_options = default_options_save
  End

  It parses ssh protocol.
    let bundle = neobundle#parser#_init_bundle(
          \ 'accountname/reponame', [{
          \ 'site' : 'github', 'type' : 'git', 'type__protocol' : 'ssh' }])
    ShouldEqual bundle.uri, 'git@github.com:accountname/reponame.git'

    let bundle = neobundle#parser#_init_bundle(
          \ 'accountname/reponame', [{
          \ 'site' : 'bitbucket', 'type' : 'hg', 'type__protocol' : 'ssh' }])
    ShouldEqual bundle.uri, 'ssh://hg@bitbucket.org/accountname/reponame'

    let bundle = neobundle#parser#_init_bundle(
          \ 'accountname/reponame.git', [{
          \ 'site' : 'bitbucket', 'type' : 'git', 'type__protocol' : 'ssh' }])
    ShouldEqual bundle.uri, 'git@bitbucket.org:accountname/reponame.git'
  End

  It fetches plugins.
    let bundle = neobundle#parser#fetch(
          \ string('accountname/reponame.git'))
    ShouldEqual bundle.rtp, ''
  End

  It parses directory
    let bundle = neobundle#parser#_init_bundle(
          \ 'Shougo/neocomplcache', [])
    ShouldEqual bundle.directory, 'neocomplcache'

    let bundle = neobundle#parser#_init_bundle(
          \ 'Shougo/neocomplcache', ['ver.3'])
    ShouldEqual bundle.directory, 'neocomplcache_ver.3'
  End

  It parses function_prefix
    ShouldEqual neobundle#parser#_function_prefix(
          \ 'neobundle.vim'), 'neobundle'

    ShouldEqual neobundle#parser#_function_prefix(
          \ 'unite-tag'), 'unite#sources#tag'

    ShouldEqual neobundle#parser#_function_prefix(
          \ 'TweetVim'), 'tweetvim'

    ShouldEqual neobundle#parser#_function_prefix(
          \ 'vim-vcs'), 'vcs'
  End

  It tests name conversion.
    let g:neobundle#enable_name_conversion = 1

    let bundle = neobundle#parser#_init_bundle(
          \ 'git://github.com/Shougo/neobundle.vim.git',
          \ [{ 'type' : 'hg'}])
    ShouldEqual bundle.name, 'neobundle'

    let bundle = neobundle#parser#_init_bundle(
          \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
          \ [{ 'type' : 'hg'}])
    ShouldEqual bundle.name, 'qt-syntax'

    let bundle = neobundle#parser#_init_bundle(
          \ 'https://bitbucket.org/kh3phr3n/qt-syntax-vim.git',
          \ [{ 'type' : 'hg'}])
    ShouldEqual bundle.name, 'qt-syntax'

    let bundle = neobundle#parser#_init_bundle(
          \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
          \ [{ 'name' : 'vim-qt-syntax'}])
    ShouldEqual bundle.name, 'vim-qt-syntax'

    let g:neobundle#enable_name_conversion = 0
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
