[![Stories in Ready](https://badge.waffle.io/Shougo/neobundle.vim.png)](https://waffle.io/Shougo/neobundle.vim)

## About

NeoBundle is a Vim plugin manager inspired by Vundle(https://github.com/gmarik/vundle).

Requirements: Vim 7.2.051 or above.

## Advantages

1. improved command name(:Bundle vs :NeoBundle).
2. neobundle works if you set 'shellslash' in your .vimrc.
3. neobundle supports vimproc(asynchronous update/install).
4. neobundle supports unite.vim interface(update/install/search).
5. neobundle supports revision lock feature.
6. neobundle supports other VCS(Subversion/Git).
7. neobundle supports lazy initialization for optimizing startup time.
8. and so on...


## Quick start

1. Setup NeoBundle:

     ```
     $ mkdir -p ~/.vim/bundle
     $ git clone https://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim
     ```

2. Configure bundles:

     Sample `.vimrc`:

     ```vim
     if has('vim_starting')
       set nocompatible               " Be iMproved
       set runtimepath+=~/.vim/bundle/neobundle.vim/
     endif

     call neobundle#rc(expand('~/.vim/bundle/'))

     " Let NeoBundle manage NeoBundle
     NeoBundleFetch 'Shougo/neobundle.vim'

     " Recommended to install
     "NeoBundle 'Shougo/vimproc', {
     " \ 'build' : {
     " \     'windows' : 'make -f make_mingw32.mak',
     " \     'cygwin' : 'make -f make_cygwin.mak',
     " \     'mac' : 'make -f make_mac.mak',
     " \     'unix' : 'make -f make_unix.mak',
     " \    },
     " \ }

     " My Bundles here:
     " Refer to |:NeoBundle-examples|.
     "
     " Note: You don't set neobundle setting in .gvimrc!

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

     Or Command run `bin/neoinstall`

## Docs

see `:h neobundle`


## Tips

If you use a single .vimrc across systems where build programs are
named differently (e.g. GNU Make is often `gmake` on non-GNU
systems), the following pattern is useful:

```vim
let g:make = 'gmake'
if system('uname -o') =~ '^GNU/'
        let g:make = 'make'
endif
NeoBundle 'Shougo/vimproc.vim', {'build': {'unix': g:make}}
```
