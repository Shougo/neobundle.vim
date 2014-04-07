#!/bin/sh
BUNDLE_DIR=~/.vim/bundle
VIMRC_PATH=~/.vimrc

# check git command
if type git; then
  : # You have git command. No Problem.
else
  echo 'Please install git command!'
  exit 1;
fi

# make bundle dir and fetch neobundle
echo "start fetch NeoBundle..."
mkdir -p $BUNDLE_DIR
git clone https://github.com/Shougo/neobundle.vim $BUNDLE_DIR/neobundle.vim
echo "done."

# write initial setting for .vimrc
echo "start write NeoBundle initial setting to ${VIMRC_PATH} ..."
{
    echo ""
    echo ""
    echo "\"NeoBundle Scripts-----------------------------"
    echo "if has('vim_starting')"
    echo "  set nocompatible               \" Be iMproved"
    echo ""
    echo "  \" Required:"
    echo "  set runtimepath+=$BUNDLE_DIR/neobundle.vim/"
    echo "endif"
    echo ""
    echo "\" Required:"
    echo "call neobundle#rc(expand('$BUNDLE_DIR'))"
    echo ""
    echo "\" Let NeoBundle manage NeoBundle"
    echo "\" Required:"
    echo "NeoBundleFetch 'Shougo/neobundle.vim'"
    echo ""
    echo "\" My Bundles here:"
    echo "NeoBundle 'Shougo/neosnippet.vim'"
    echo "NeoBundle 'Shougo/neosnippet-snippets'"
    echo "NeoBundle 'tpope/vim-fugitive'"
    echo "NeoBundle 'kien/ctrlp.vim'"
    echo "NeoBundle 'flazz/vim-colorschemes'"
    echo ""
    echo "\" You can specify revision/branch/tag."
    echo "NeoBundle 'Shougo/vimshell', { 'rev' : '3787e5' }"
    echo ""
    echo "\" Required:"
    echo "filetype plugin indent on"
    echo ""
    echo "\" If there are uninstalled bundles found on startup,"
    echo "\" this will conveniently prompt you to install them."
    echo "NeoBundleCheck"
    echo "\"End NeoBundle Scripts-------------------------"
    echo ""
    echo ""
} >> ${VIMRC_PATH}
echo "done."

# open neobundle official page.
echo "complete setup NeoBundle!"
echo "open NeoBundle github page. enjoy!!"
open https://github.com/Shougo/neobundle.vim
