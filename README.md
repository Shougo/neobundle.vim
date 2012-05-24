## About

NeoBundle is Vim plugin manager based on Vundle(https://github.com/gmarik/vundle).

## Quick start

1. Setup NeoBundle:

     ```
     $ mkdir -p ~/.vim/bundle
     $ git clone https://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim
     ```

2. Configure bundles:

     Sample `.vimrc`:

     ```vim
     set nocompatible               " be iMproved
     filetype off                   " required!
     filetype plugin indent off     " required!

     if has('vim_starting')
       set runtimepath+=~/.vim/bundle/neobundle.vim/
       call neobundle#rc(expand('~/.vim/bundle/'))
     endif
     " let NeoBundle manage NeoBundle
     " required! 
     "NeoBundle 'Shougo/neobundle.vim'
     " recommended to install
     NeoBundle 'Shougo/vimproc'
     " after install, turn shell ~/.vim/bundle/vimproc, (n,g)make -f your_machines_makefile
     NeoBundle 'Shougo/vimshell'
     NeoBundle 'Shougo/unite.vim'

     " My Bundles here:
     "
     " original repos on github
     NeoBundle 'tpope/vim-fugitive'
     NeoBundle 'Lokaltog/vim-easymotion'
     NeoBundle 'rstacruz/sparkup', {'rtp': 'vim/'}
     " vim-scripts repos
     NeoBundle 'L9'
     NeoBundle 'FuzzyFinder'
     NeoBundle 'rails.vim'
     " non github repos
     NeoBundle 'git://git.wincent.com/command-t.git'
     " non git repos
     NeoBundle 'http://svn.macports.org/repository/macports/contrib/mpvim/'
     NeoBundle 'https://bitbucket.org/ns9tks/vim-fuzzyfinder'

     " ...

     filetype plugin indent on     " required!
     "
     " Brief help
     " :NeoBundleList          - list configured bundles
     " :NeoBundleInstall(!)    - install(update) bundles
     " :NeoBundleClean(!)      - confirm(or auto-approve) removal of unused bundles
     "
     ```
3. Install configured bundles:

     Launch `vim`, run `:NeoBundleInstall`, or `:Unite neobundle/install:!`(required unite.vim)
## Docs

see `:h neobundle`
