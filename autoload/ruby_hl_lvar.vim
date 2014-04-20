let g:ruby_hl_lvars_hl_group =
	\ get(g:, 'ruby_hl_lvars_hl_group', 'Identifier')


let s:self_path=expand("<sfile>")

execute 'rubyfile '.s:self_path.'.rb'

" bufnr => match_id
let s:match_ids = {}

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

function! ruby_hl_lvar#highlight(buffer) abort
	let bufnr = bufnr(a:buffer)
	let matches = map(ruby_hl_lvar#extract_lvars(a:buffer), '
		\ ''\%''.v:val[1].''l''.''\%''.v:val[2].''c''.repeat(''.'', strchars(v:val[0]))
		\ ')
	if has_key(s:match_ids, bufnr) && s:match_ids[bufnr] > 0
		call matchdelete(s:match_ids[bufnr])
	endif
	let s:match_ids[bufnr] = matchadd(g:ruby_hl_lvars_hl_group, join(matches, '\|'))
endfunction

