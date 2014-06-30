scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

function! s:comp_bundle(bundle1, bundle2)
  return a:bundle1.name > a:bundle2.name
endfunction

function! s:clear_bundles(names)
  for bundle in neobundle#config#search(a:names)
    call neobundle#config#rm(bundle.path)
  endfor
endfunction

function! s:rotate_bundle(bundles)
  return a:bundles[1:-1]+a:bundles[0:0]
endfunction

Context tsort
  It tsort no depends
    " [a, b, c] => [a, b, c]
    let g:neobundle_test_data = [{'name' : 'a'}, {'name' : 'b'}, {'name' : 'c'},]
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data), g:neobundle_test_data
    unlet! g:neobundle_test_data
  End

  It tsort normal
    " a -> b -> c
    " b -> d
    " c
    " [a, b, c] => [c, b, a]
    let g:neobundle_test_data = [
    \   {'name' : 'a', 'depends' : [
    \     {'name' : 'b', 'depends' : [
    \       {'name' : 'c'},
    \     ]},
    \   ]},
    \   {'name' : 'b', 'skip' : 1, 'depends' : [
    \       {'name' : 'd', 'skipped' : 1, },
    \   ]},
    \   {'name' : 'c', 'skip' : 1},
    \ ]
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data), [
    \   g:neobundle_test_data[0].depends[0].depends[0],
    \   g:neobundle_test_data[0].depends[0],
    \   g:neobundle_test_data[0],
    \ ]
    unlet! g:neobundle_test_data

    " a -> c -> b
    " a -> d
    " b
    " c
    " [a, b, c] => [b, c, d, a]
    let g:neobundle_test_data = [
    \   {'name' : 'a', 'depends' : [
    \     {'name' : 'c', 'depends' : [
    \       {'name' : 'b'},
    \     ]},
    \     {'name' : 'd'},
    \   ]},
    \   {'name' : 'b', 'skip' : 1},
    \   {'name' : 'c', 'skip' : 1},
    \ ]
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data),
    \ [
    \   g:neobundle_test_data[0].depends[0].depends[0],
    \   g:neobundle_test_data[0].depends[0],
    \   g:neobundle_test_data[0].depends[1],
    \   g:neobundle_test_data[0],
    \ ]
    unlet! g:neobundle_test_data
  End

  It tsort circular reference
    " a -> b -> c -> a
    " b
    " c
    " [a, b, c] => [c, b, a]
    let g:neobundle_test_data = [
    \   {'name' : 'a', 'depends' : [
    \     {'name' : 'b', 'depends' : [
    \       {'name' : 'c', 'depends' : [
    \         {'name' : 'a', 'skip' : 1},
    \       ]},
    \     ]},
    \   ]},
    \   {'name' : 'b', 'skip' : 1},
    \   {'name' : 'c', 'skip' : 1},
    \ ]
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data),
    \ [
    \   g:neobundle_test_data[0].depends[0].depends[0],
    \   g:neobundle_test_data[0].depends[0],
    \   g:neobundle_test_data[0],
    \ ]
    unlet! g:neobundle_test_data
  End

  It tsort bundled no depends
    NeoBundleLazy 'a/a'
    NeoBundleLazy 'b/b'
    NeoBundleLazy 'c/c'
    let g:neobundle_test_data = sort(filter(neobundle#config#get_neobundles(), "v:val.name =~# '^[abc]$'"), "s:comp_bundle")

    " [a, b, c] => [a, b, c]
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data), g:neobundle_test_data

    " [c, b, a] => [c, b, a]
    call reverse(g:neobundle_test_data)
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data), g:neobundle_test_data

    unlet! g:neobundle_test_data
    call s:clear_bundles(['a','b','c'])
  End

  It tsort bundled normal
    NeoBundleLazy 'a/a'
    NeoBundleLazy 'b/b', {'depends' : 'a/a'}
    NeoBundleLazy 'c/c', {'depends' : 'b/b'}
    let g:neobundle_test_data = sort(filter(neobundle#config#get_neobundles(), "v:val.name =~# '^[abc]$'"), "s:comp_bundle")

    " [a, b, c] => [a, b, c]
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data), g:neobundle_test_data

    " [c, b, a] => [a, b, c]
    ShouldEqual neobundle#config#tsort(reverse(copy(g:neobundle_test_data))), g:neobundle_test_data

    unlet! g:neobundle_test_data
    call s:clear_bundles(['a','b','c'])

    NeoBundleLazy 'a/a', {'depends' : ['c/c', 'b/b']}
    NeoBundleLazy 'b/b'
    NeoBundleLazy 'c/c', {'depends' : 'b/b'}
    let g:neobundle_test_data = sort(filter(neobundle#config#get_neobundles(), "v:val.name =~# '^[abc]$'"), "s:comp_bundle")
    let g:neobundle_test_rotated = s:rotate_bundle(g:neobundle_test_data)

    " [a, b, c] => [b, c, a]
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data), g:neobundle_test_rotated

    " [c, b, a] => [b, c, a]
    ShouldEqual neobundle#config#tsort(reverse(copy(g:neobundle_test_data))), g:neobundle_test_rotated

    unlet! g:neobundle_test_data g:neobundle_test_rotated
    call s:clear_bundles(['a','b','c'])
  End

  It tsort bundled circular reference
    NeoBundleLazy 'a/a', {'depends' : 'b/b'}
    NeoBundleLazy 'b/b', {'depends' : 'c/c'}
    NeoBundleLazy 'c/c', {'depends' : 'a/a'}
    let g:neobundle_test_data = sort(filter(neobundle#config#get_neobundles(), "v:val.name =~# '^[abc]$'"), "s:comp_bundle")

    " [a, b, c] => [c, b, a]
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data), reverse(copy(g:neobundle_test_data))

    " [c, b, a] => [b, a, c]
    call reverse(g:neobundle_test_data)
    let g:neobundle_test_rotated = s:rotate_bundle(g:neobundle_test_data)
    ShouldEqual neobundle#config#tsort(g:neobundle_test_data), g:neobundle_test_rotated

    unlet! g:neobundle_test_data g:neobundle_test_rotated
    call s:clear_bundles(['a','b','c'])
  End
End

Fin

delfunction s:comp_bundle
delfunction s:clear_bundles
delfunction s:rotate_bundle

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
