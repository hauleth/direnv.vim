" direnv.vim - support for direnv <http://direnv.net>
" Author:       zimbatm <http://zimbatm.com/> & Hauleth <lukasz@niemier.pl>
" Version:      0.2

if exists('g:loaded_direnv') || &cp || v:version < 700
  finish
endif
let g:loaded_direnv = 1

let s:direnv_cmd = get(g:, 'direnv_cmd', 'direnv')
let s:direnv_auto = get(g:, 'direnv_auto', 1)

let s:job = { 'running': 0, 'stdout': [''], 'stderr': [''] }
" NeoVim {{{
func! s:job.on_stdout(_, data, ...) abort
  let self.stdout[-1] .= a:data[0]
  call extend(self.stdout, a:data[1:])
endfunc
func! s:job.on_stderr(_, data, ...) abort
  let self.stderr[-1] .= a:data[0]
  call extend(self.stderr, a:data[1:])
endfunc
func! s:job.on_exit(_, status, ...) abort
  let self.running = 0

  for m in self.stderr
    if m isnot# ''
      echom m
    endif
  endfor
  exe join(self.stdout, "\n")
endfunc
" }}}
" Vim {{{
func! s:job.err_cb(_, data) abort
  call self.on_stderr(0, split(a:data, "\n", 1))
endfunc
func! s:job.out_cb(_, data) abort
  call self.on_stdout(0, split(a:data, "\n", 1))
endfunc
func! s:job.exit_cb(_, status) abort
  call self.on_exit(0, a:status)
endfunc
" }}}

func! direnv#export() abort
  if !executable(s:direnv_cmd)
    echoerr 'No Direnv executable, add it to your PATH or set correct g:direnv_cmd'
    return
  endif
  if s:job.running
    return
  endif

  let s:job.running = 1
  let l:cmd = [s:direnv_cmd, 'export', 'vim']
  if has('nvim')
    call jobstart(l:cmd, s:job)
  elseif has('job') && has('channel')
    call job_start(l:cmd, s:job)
  else
    let l:tmp = tempname()
    echom system(printf(join(l:cmd).' '.&shellredir, l:tmp))
    exe 'source '.l:tmp
    call delete(l:tmp)
  endif
endfunc

command! -nargs=0 DirenvExport call direnv#export()

augroup envrc
  au!
  autocmd BufRead,BufNewFile .envrc set filetype=sh
  autocmd BufWritePost .envrc DirenvExport

  if s:direnv_auto
    autocmd VimEnter * DirenvExport

    if exists('##DirChanged')
      autocmd DirChanged * DirenvExport
    else
      autocmd BufEnter * DirenvExport
    endif
  endif
augroup END

" vi: fdm=marker sw=2 sts=2 et
