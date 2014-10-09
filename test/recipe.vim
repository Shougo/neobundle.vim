" Recipe installation test.
set verbose=1

let path = expand('~/test-bundle/'.fnamemodify(expand('<sfile>'), ':t:r'))

if isdirectory(path)
  let rm_command = neobundle#util#is_windows() ? 'rmdir /S /Q' : 'rm -rf'
  call system(printf('%s "%s"', rm_command, path))
endif

call neobundle#begin(path)

" Let NeoBundle manage NeoBundle
NeoBundleFetch 'Shougo/neobundle.vim'

" Use recipe.
NeoBundle 'Shougo/neobundle-vim-recipes'
NeoBundleRecipe 'vinarise'
NeoBundle 'Shougo/neocomplcache-snippets-complete',
      \ { 'recipe' : 'neocomplcache-snippets-complete'}

call neobundle#end()

filetype plugin indent on     " Required!

