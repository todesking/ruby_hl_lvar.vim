if !has('ruby')
	echoerr "ruby_hl_lvar: This plugin does not work without has('ruby')"
	finish
endif

let g:ruby_hl_lvar_hl_group =
	\ get(g:, 'ruby_hl_lvar_hl_group', 'Identifier')

let g:ruby_hl_lvar_auto_enable =
	\ get(g:, 'ruby_hl_lvar_auto_enable', 1)

let g:ruby_hl_lvar_show_warnings =
	\ get(g:, 'ruby_hl_lvar_show_warnings', 0)

let g:ruby_hl_lvar_highlight_priority =
	\ get(g:, 'ruby_hl_lvar_highlight_priority', 0)

augroup ruby_hl_lvar
	autocmd!
	autocmd Filetype    * call Ruby_hl_lvar_filetype()
	autocmd BufWinLeave * call ruby_hl_lvar#redraw()
	autocmd BufWinEnter * call ruby_hl_lvar#redraw()
	autocmd WinEnter    * call ruby_hl_lvar#redraw()
	autocmd WinLeave    * call ruby_hl_lvar#redraw()
	autocmd TabEnter    * call ruby_hl_lvar#redraw()
	autocmd TabLeave    * call ruby_hl_lvar#redraw()
augroup END

function! Ruby_hl_lvar_filetype()
	if &filetype !~# '\<ruby\>'
		return
	endif

	if !g:ruby_hl_lvar_auto_enable
		return ruby_hl_lvar#disable(1)
	endif

	call ruby_hl_lvar#refresh(1)
	augroup ruby_hl_lvar
		autocmd! * <buffer>
		autocmd TextChanged <buffer> call ruby_hl_lvar#refresh(0)
		autocmd InsertEnter <buffer> call ruby_hl_lvar#disable(0)
		autocmd InsertLeave <buffer> call ruby_hl_lvar#refresh(0)
	augroup END
endfunction

nmap <Plug>(ruby_hl_lvar-enable) :<C-U>call ruby_hl_lvar#enable(1)<CR>
nmap <Plug>(ruby_hl_lvar-disable) :<C-U>call ruby_hl_lvar#disable(1)<CR>
nmap <Plug>(ruby_hl_lvar-refresh) :<C-U>call ruby_hl_lvar#refresh(1)<CR>
