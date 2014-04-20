let s:self_path=expand("<sfile>")

execute 'rubyfile '.s:self_path.'.rb'

" return: [[var_name, row, col_start, col_end]...]
function! ruby_hl_lvar#extract_lvars(buffer) abort
  let bufnr = bufnr(a:buffer)
  if exists('s:ret')
    unlet s:ret
  endif
  let t = reltime()
  execute 'ruby RubyHlLvar::Vim.extract_lvars_from '.bufnr
  let b:ruby_hl_lvar_time = str2float(reltimestr(reltime(t)))
  let ret = s:ret
  unlet s:ret
  return ret
endfunction

function! ruby_hl_lvar#disable(buffer, force) abort
	if !a:force && exists('b:ruby_hl_lvar_enabled') && !b:ruby_hl_lvar_enabled
		return
	endif
	let bufnr = bufnr(a:buffer)
	if exists('b:ruby_hl_lvar_match_id') && b:ruby_hl_lvar_match_id > 0
		call s:try_matchdelete(b:ruby_hl_lvar_match_id)
		unlet b:ruby_hl_lvar_match_id
	endif
	if a:force
		let b:ruby_hl_lvar_enabled = 0
	endif
endfunction

function! s:try_matchdelete(id)
	try
		call matchdelete(a:id)
	catch /E803:/
	endtry
endfunction

function! ruby_hl_lvar#enable(buffer, force) abort
	if !a:force && exists('b:ruby_hl_lvar_enabled') && !b:ruby_hl_lvar_enabled
		return
	endif
	let bufnr = bufnr(a:buffer)
	call ruby_hl_lvar#disable(a:buffer, a:force)
	if !exists('b:ruby_hl_lvar_match_pattern')
		call ruby_hl_lvar#update_match_pattern(a:buffer)
	endif
	let b:ruby_hl_lvar_match_id = matchadd(g:ruby_hl_lvar_hl_group, b:ruby_hl_lvar_match_pattern)
	if a:force
		let b:ruby_hl_lvar_enabled = 1
	endif
endfunction

function! ruby_hl_lvar#refresh(buffer, force) abort
	if !a:force && exists('b:ruby_hl_lvar_enabled') && !b:ruby_hl_lvar_enabled
		return
	endif
	let bufnr = bufnr(a:buffer)
	if exists('b:ruby_hl_lvar_match_pattern')
		unlet b:ruby_hl_lvar_match_pattern
	endif
	call ruby_hl_lvar#enable(a:buffer, a:force)
endfunction

function! ruby_hl_lvar#update_match_pattern(buffer) abort
	let bufnr = bufnr(a:buffer)
	let matches = map(ruby_hl_lvar#extract_lvars(a:buffer), '
		\ ''\%''.v:val[1].''l''.''\%''.v:val[2].''c''.repeat(''.'', strchars(v:val[0]))
		\ ')
	let b:ruby_hl_lvar_match_pattern = join(matches, '\|')
endfunction

