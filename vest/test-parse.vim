scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

Context types
  It parses github git repos
    Should neobundle#config#parse_path(
          \ 'Shougo/neocomplcache-clang.git') ==
          \ {'type' : 'git', 'uri' :
          \   g:neobundle_default_git_protocol .
          \  '://github.com/Shougo/neocomplcache-clang.git',
          \  'name' : 'neocomplcache-clang'}
    Should neobundle#config#parse_path('Shougo/vimshell') ==
          \ {'type' : 'git', 'uri' :
          \   g:neobundle_default_git_protocol .
          \  '://github.com/Shougo/vimshell.git',
          \  'name' : 'vimshell'}
    Should neobundle#config#parse_path('rails.vim') ==
          \ {'type' : 'git', 'uri' :
          \ g:neobundle_default_git_protocol .
          \ '://github.com/vim-scripts/rails.vim.git',
          \  'name' : 'rails.vim'}
    Should neobundle#config#parse_path(
          \ 'git://git.wincent.com/command-t.git') ==
          \ {'type' : 'git', 'uri' :
          \  'git://git.wincent.com/command-t.git',
          \  'name' : 'command-t'}
    Should neobundle#config#parse_path('vim-scripts/ragtag.vim') ==
          \ {'type' : 'git', 'uri' :
          \ g:neobundle_default_git_protocol .
          \ '://github.com/vim-scripts/ragtag.vim.git',
          \  'name' : 'ragtag.vim'}
    Should neobundle#config#parse_path(
          \ 'https://github.com/vim-scripts/vim-game-of-life') ==
          \ {'type' : 'git', 'uri' :
          \ 'https://github.com/vim-scripts/vim-game-of-life.git',
          \  'name' : 'vim-game-of-life'}
    Should neobundle#config#parse_path(
          \ 'git@github.com:gmarik/ingretu.git') ==
          \ {'type' : 'git', 'uri' :
          \ 'git@github.com:gmarik/ingretu.git',
          \  'name' : 'ingretu'}
    Should neobundle#config#parse_path(
          \ 'gh:gmarik/snipmate.vim.git') ==
          \ {'type' : 'git', 'uri' :
          \ g:neobundle_default_git_protocol .
          \ '://github.com/gmarik/snipmate.vim.git',
          \  'name' : 'snipmate.vim'}
    Should neobundle#config#parse_path(
          \ 'github:mattn/gist-vim.git') ==
          \ {'type' : 'git', 'uri' :
          \ g:neobundle_default_git_protocol .
          \ '://github.com/mattn/gist-vim.git',
          \  'name' : 'gist-vim'}
    Should neobundle#config#parse_path(
          \ 'git@github.com:Shougo/neocomplcache.git') ==
          \ {'type' : 'git', 'uri' :
          \ 'git@github.com:Shougo/neocomplcache.git',
          \  'name' : 'neocomplcache'}
  End

  It parse svn repos
    Should neobundle#config#parse_path(
          \ 'http://svn.macports.org/repository/macports/contrib/mpvim/') ==
          \ {'type' : 'svn', 'uri' :
          \  'http://svn.macports.org/repository/macports/contrib/mpvim/',
          \  'name' : 'mpvim'}
  End

  It parses bitbucket hg repos
    Should neobundle#config#parse_path(
          \ 'https://bitbucket.org/ns9tks/vim-fuzzyfinder') ==
          \ {'type' : 'hg', 'uri' :
          \  'https://bitbucket.org/ns9tks/vim-fuzzyfinder',
          \  'name' : 'vim-fuzzyfinder'}
    Should neobundle#config#parse_path(
          \ 'bitbucket://bitbucket.org/ns9tks/vim-fuzzyfinder') ==
          \ {'type' : 'hg', 'uri' :
          \  g:neobundle_default_hg_protocol.
          \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
          \  'name' : 'vim-fuzzyfinder'}
    Should neobundle#config#parse_path(
          \ 'bitbucket:ns9tks/vim-fuzzyfinder') ==
          \ {'type' : 'hg', 'uri' :
          \  g:neobundle_default_hg_protocol.
          \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
          \  'name' : 'vim-fuzzyfinder'}
    Should neobundle#config#parse_path(
          \ 'ns9tks/vim-fuzzyfinder', {'site': 'bitbucket'}) ==
          \ {'type' : 'hg', 'uri' :
          \  g:neobundle_default_hg_protocol.
          \  '://bitbucket.org/ns9tks/vim-fuzzyfinder',
          \  'name' : 'vim-fuzzyfinder'}

    let bundle = neobundle#config#init_bundle(
          \ 'git://github.com/Shougo/neobundle.vim.git',
          \ [{ 'type' : 'hg'}])
    Should bundle.name == 'neobundle.vim'
    Should bundle.type == 'hg'
    Should bundle.uri == 'git://github.com/Shougo/neobundle.vim.git'
  End

  It parses bitbucket git repos
    Should neobundle#config#parse_path(
          \ 'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git') ==
          \ {'type' : 'git', 'uri' :
          \  'https://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
          \  'name' : 'vim-qt-syntax'}
    Should neobundle#config#parse_path(
          \ 'bitbucket:kh3phr3n/vim-qt-syntax.git') ==
          \ {'type' : 'git', 'uri' :
          \  g:neobundle_default_git_protocol.
          \  '://bitbucket.org/kh3phr3n/vim-qt-syntax.git',
          \  'name' : 'vim-qt-syntax'}
  End
End

Fin

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}

" vim:foldmethod=marker:fen:
