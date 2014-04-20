if !has('ruby')
	echoerr "ruby_hl_lvar: This plugin does not work without has('ruby')"
	finish
endif

let g:ruby_hl_lvar_hl_group =
	\ get(g:, 'ruby_hl_lvar_hl_group', 'Identifier')

let g:ruby_hl_lvar_auto_enable =
	\ get(g:, 'ruby_hl_lvar_auto_enable', 1)

if g:ruby_hl_lvar_auto_enable
	augroup ruby_hl_lvar
		autocmd!
		autocmd! Filetype * call Ruby_hl_lvar_filetype()
	augroup END
endif

function! Ruby_hl_lvar_filetype()
	let groupname = 'vim_hl_lvar_'.bufnr('%')
	execute 'augroup '.groupname
		autocmd!
		if &filetype ==# 'ruby'
			autocmd TextChanged <buffer> call ruby_hl_lvar#refresh('%', 0)
			autocmd InsertEnter <buffer> call ruby_hl_lvar#disable('%', 0)
			autocmd InsertLeave <buffer> call ruby_hl_lvar#refresh('%', 0)
			autocmd BufWinEnter <buffer> call ruby_hl_lvar#enable('%', 0)
			autocmd BufWinLeave <buffer> call ruby_hl_lvar#disable('%', 0)
		endif
	augroup END
endfunction

nmap <Plug>(ruby_hl_lvar-enable) :<C-U>call ruby_hl_lvar#enable('%', 1)<CR>
nmap <Plug>(ruby_hl_lvar-disable) :<C-U>call ruby_hl_lvar#disable('%', 1)<CR>
nmap <Plug>(ruby_hl_lvar-refresh) :<C-U>call ruby_hl_lvar#refresh('%', 1)<CR>
