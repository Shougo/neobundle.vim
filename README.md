## About

NeoBundle is a Vim plugin manager inspired by Vundle(https://github.com/gmarik/vundle).

## Quick start

1. Setup NeoBundle:

     ```
     $ mkdir -p ~/.vim/bundle
     $ git clone git://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim
     ```

2. Configure bundles:

     Sample `.vimrc`:

     ```vim
     set nocompatible               " Be iMproved

     if has('vim_starting')
       set runtimepath+=~/.vim/bundle/neobundle.vim/
     endif

     call neobundle#rc(expand('~/.vim/bundle/'))

     " Let NeoBundle manage NeoBundle
     NeoBundleFetch 'Shougo/neobundle.vim'

     " Recommended to install
     " After install, turn shell ~/.vim/bundle/vimproc, (n,g)make -f your_machines_makefile
     NeoBundle 'Shougo/vimproc'

     " My Bundles here:
     "
     " Note: You don't set neobundle setting in .gvimrc!
     " Original repos on github
     NeoBundle 'tpope/vim-fugitive'
     NeoBundle 'Lokaltog/vim-easymotion'
     NeoBundle 'rstacruz/sparkup', {'rtp': 'vim/'}
     " vim-scripts repos
     NeoBundle 'L9'
     NeoBundle 'FuzzyFinder'
     NeoBundle 'rails.vim'
     " Non github repos
     NeoBundle 'git://git.wincent.com/command-t.git'
     " gist repos
     NeoBundle 'gist:Shougo/656148', {
           \ 'name': 'everything.vim',
           \ 'script_type': 'plugin'}
     " Non git repos
     NeoBundle 'http://svn.macports.org/repository/macports/contrib/mpvim/'
     NeoBundle 'https://bitbucket.org/ns9tks/vim-fuzzyfinder'

     " ...

     filetype plugin indent on     " Required!
     "
     " Brief help
     " :NeoBundleList          - list configured bundles
     " :NeoBundleInstall(!)    - install(update) bundles
     " :NeoBundleClean(!)      - confirm(or auto-approve) removal of unused bundles

     " Installation check.
     NeoBundleCheck
     ```
3. Install configured bundles:

     Launch `vim`, run `:NeoBundleInstall`, or `:Unite neobundle/install`(required unite.vim)

## Docs

see `:h neobundle`
