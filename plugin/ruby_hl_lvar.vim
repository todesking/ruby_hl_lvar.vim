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

augroup ruby_hl_lvar
	autocmd!
	autocmd! Filetype * call Ruby_hl_lvar_filetype()
augroup END

autocmd BufWinEnter * call ruby_hl_lvar#redraw()
autocmd BufWinLeave * call ruby_hl_lvar#redraw()
autocmd WinEnter    * call ruby_hl_lvar#redraw()
autocmd WinLeave    * call ruby_hl_lvar#redraw()
autocmd TabEnter    * call ruby_hl_lvar#redraw()
autocmd TabLeave    * call ruby_hl_lvar#redraw()

function! Ruby_hl_lvar_filetype()
	let groupname = 'vim_hl_lvar_'.bufnr('%')
	execute 'augroup '.groupname
		autocmd!
		if &filetype =~# '\<ruby\>'
			if g:ruby_hl_lvar_auto_enable
				call ruby_hl_lvar#refresh(1)
				autocmd TextChanged <buffer> call ruby_hl_lvar#refresh(0)
				autocmd InsertEnter <buffer> call ruby_hl_lvar#disable(0)
				autocmd InsertLeave <buffer> call ruby_hl_lvar#refresh(0)
			else
				call ruby_hl_lvar#disable(1)
			endif
		endif
	augroup END
endfunction

nmap <Plug>(ruby_hl_lvar-enable) :<C-U>call ruby_hl_lvar#enable(1)<CR>
nmap <Plug>(ruby_hl_lvar-disable) :<C-U>call ruby_hl_lvar#disable(1)<CR>
nmap <Plug>(ruby_hl_lvar-refresh) :<C-U>call ruby_hl_lvar#refresh(1)<CR>
