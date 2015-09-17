#!/bin/sh
# Standalone installer for Unixs
# Original version is created by shoma2da
# https://github.com/shoma2da/neobundle_installer

# Installation directory
BUNDLE_DIR=~/.vim/bundle
INSTALL_DIR="$BUNDLE_DIR/neobundle.vim"
echo "$INSTALL_DIR"
if [ -e "$INSTALL_DIR" ]; then
  echo "$INSTALL_DIR already exists!"
  exit 1
fi

# check git command
if type git; then
  : # You have git command. No Problem.
else
  echo 'Please install git or update your path to include the git executable!'
  exit 1;
fi

# make bundle dir and fetch neobundle
echo "Begin fetching NeoBundle..."
mkdir -p "$BUNDLE_DIR"
git clone https://github.com/Shougo/neobundle.vim "$INSTALL_DIR"
echo "Done."

# write initial setting for .vimrc
echo "Please add the following settings for NeoBundle to the top of your .vimrc file:"
{
    echo ""
    echo ""
    echo "\"NeoBundle Scripts-----------------------------"
    echo "if has('vim_starting')"
    echo "  if &compatible"
    echo "    set nocompatible               \" Be iMproved"
    echo "  endif"
    echo ""
    echo "  \" Required:"
    echo "  set runtimepath+=$BUNDLE_DIR/neobundle.vim/"
    echo "endif"
    echo ""
    echo "\" Required:"
    echo "call neobundle#begin(expand('$BUNDLE_DIR'))"
    echo ""
    echo "\" Let NeoBundle manage NeoBundle"
    echo "\" Required:"
    echo "NeoBundleFetch 'Shougo/neobundle.vim'"
    echo ""
    echo "\" Add or remove your Bundles here:"
    echo "NeoBundle 'Shougo/neosnippet.vim'"
    echo "NeoBundle 'Shougo/neosnippet-snippets'"
    echo "NeoBundle 'tpope/vim-fugitive'"
    echo "NeoBundle 'ctrlpvim/ctrlp.vim'"
    echo "NeoBundle 'flazz/vim-colorschemes'"
    echo ""
    echo "\" You can specify revision/branch/tag."
    echo "NeoBundle 'Shougo/vimshell', { 'rev' : '3787e5' }"
    echo ""
    echo "\" Required:"
    echo "call neobundle#end()"
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
}
echo "Done."

echo "Complete setup NeoBundle!"
