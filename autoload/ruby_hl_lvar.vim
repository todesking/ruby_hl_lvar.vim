let s:self_path=expand("<sfile>")

execute 'rubyfile '.s:self_path.'.rb'

" bufnr => match_id
let s:match_ids = {}

" bufnr => match_pattern
let s:match_patterns = {}

" return: [[var_name, row, col_start, col_end]...]
function! ruby_hl_lvar#extract_lvars(buffer) abort
  let bufnr = bufnr(a:buffer)
  if exists('s:ret')
    unlet s:ret
  endif
  execute 'ruby RubyHlLvar::Vim.extract_lvars_from '.bufnr
  let ret = s:ret
  unlet s:ret
  return ret
endfunction

function! ruby_hl_lvar#disable(buffer, force) abort
	if !a:force && exists('b:ruby_hl_lvar_enabled') && !b:ruby_hl_lvar_enabled
		return
	endif
	let bufnr = bufnr(a:buffer)
	if has_key(s:match_ids, bufnr) && s:match_ids[bufnr] > 0
		try
			call matchdelete(s:match_ids[bufnr])
		catch /^E803:/
		endtry
		unlet s:match_ids[bufnr]
	endif
	if a:force
		let b:ruby_hl_lvar_enabled = 0
	endif
endfunction

function! ruby_hl_lvar#enable(buffer, force) abort
	if !a:force && exists('b:ruby_hl_lvar_enabled') && !b:ruby_hl_lvar_enabled
		return
	endif
	let bufnr = bufnr(a:buffer)
	call ruby_hl_lvar#disable(a:buffer, a:force)
	if !has_key(s:match_patterns, bufnr)
		call ruby_hl_lvar#update_match_pattern(a:buffer)
	endif
	let s:match_ids[bufnr] = matchadd(g:ruby_hl_lvar_hl_group, s:match_patterns[bufnr])
	if a:force
		let b:ruby_hl_lvar_enabled = 1
	endif
endfunction

function! ruby_hl_lvar#refresh(buffer, force) abort
	if !a:force && exists('b:ruby_hl_lvar_enabled') && !b:ruby_hl_lvar_enabled
		return
	endif
	let bufnr = bufnr(a:buffer)
	if has_key(s:match_patterns, bufnr)
		unlet s:match_patterns[bufnr]
	endif
	call ruby_hl_lvar#enable(a:buffer, a:force)
endfunction

function! ruby_hl_lvar#update_match_pattern(buffer) abort
	let bufnr = bufnr(a:buffer)
	let matches = map(ruby_hl_lvar#extract_lvars(a:buffer), '
		\ ''\%''.v:val[1].''l''.''\%''.v:val[2].''c''.repeat(''.'', strchars(v:val[0]))
		\ ')
	let s:match_patterns[bufnr] = join(matches, '\|')
endfunction

