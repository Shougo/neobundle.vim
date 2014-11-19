let s:suite = themis#suite('toml')
let s:assert = themis#helper('assert')

let g:path = expand('~/test-bundle/'.fnamemodify(expand('<sfile>'), ':t:r'))

function! s:suite.before_each()
  let g:temp = tempname()
  call neobundle#begin(g:path)
endfunction

function! s:suite.after_each()
  call neobundle#end()
  call delete(g:temp)
endfunction

function! s:suite.no_toml()
  call writefile([
        \ 'foobar'
        \ ], g:temp)
  call s:assert.equals(neobundle#parser#load_toml(g:temp, {}), 1)
endfunction

function! s:suite.no_plugins()
  call writefile([], g:temp)
  call s:assert.equals(neobundle#parser#load_toml(g:temp, {}), 1)
endfunction

function! s:suite.no_repository()
  call writefile([
        \ "[[plugins]]",
        \ "filetypes = 'all'",
        \ "[[plugins]]",
        \ "filetypes = 'all'"
        \ ], g:temp)
  call s:assert.equals(neobundle#parser#load_toml(g:temp, {}), 1)
endfunction

function! s:suite.normal()
  call writefile([
        \ "[[plugins]]",
        \ "repository = 'Shougo/tabpagebuffer.vim'",
        \ "filetypes = 'all'",
        \ "[[plugins]]",
        \ "repository = 'Shougo/tabpagebuffer.vim'",
        \ "filetypes = 'all'"
        \ ], g:temp)
  call s:assert.equals(neobundle#parser#load_toml(g:temp, {}), 0)
endfunction

