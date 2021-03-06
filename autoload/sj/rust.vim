let s:skip_syntax = sj#SkipSyntax(['rustString', 'rustCommentLine', 'rustCommentBlock'])

function! sj#rust#SplitMatchClause()
  if !sj#SearchUnderCursor('^.*\s*=>\s*.*$')
    return 0
  endif

  call search('=>\s*\zs.', 'W', line('.'))

  let start_col = col('.')
  if !search(',\s*\%(//.*\)\=$', 'W', line('.'))
    return 0
  endif
  let comma_col = col('.')
  let end_col = comma_col - 1

  let body = sj#GetCols(start_col, end_col)
  call sj#ReplaceCols(start_col, comma_col, "{\n".body."\n},")
  return 1
endfunction

function! sj#rust#JoinMatchClause()
  if !sj#SearchUnderCursor('^.*\s*=>\s*{\s*$')
    return 0
  endif

  call search('=>\s*\zs{', 'W', line('.'))

  let body = sj#Trim(sj#GetMotion('Vi{'))
  if stridx(body, "\n") >= 0
    return 0
  endif

  call sj#ReplaceMotion('Va{', body)
  return 1
endfunction

function! sj#rust#SplitQuestionMark()
  if sj#SearchSkip('.?', s:skip_syntax, 'Wc', line('.')) <= 0
    return 0
  endif

  let current_line = line('.')
  let end_col = col('.')
  let question_mark_col = col('.') + 1
  let char = getline('.')[end_col - 1]

  if char =~ '\k'
    call search('\k\+?;', 'bWc', line('.'))
    let start_col = col('.')
  elseif char == '}'
    " go to opening bracket
    normal! %
    let start_col = col('.')
  elseif char == ')'
    " go to opening bracket
    normal! %
    " find first method-call char
    call search('\%(\k\|\.\|::\)\+!\?(', 'bWc')

    if line('.') != current_line
      " multiline expression, let's just ignore it
      return 0
    endif

    let start_col = col('.')
  endif

  let expr = sj#GetCols(start_col, end_col)
  let replacement = join([
        \   "match ".expr." {",
        \   "  Ok(value) => value,",
        \   "  Err(e) => return Err(e.into()),",
        \   "}"
        \ ], "\n")

  call sj#ReplaceCols(start_col, question_mark_col, replacement)
  return 1
endfunction

function! sj#rust#JoinQuestionMark()
  let match_pattern = '\<match .* {$'

  if sj#SearchSkip(match_pattern, s:skip_syntax, 'Wc', line('.')) <= 0
        \ && sj#SearchSkip(match_pattern, s:skip_syntax, 'Wbc', line('.')) <= 0
    return 0
  endif

  let match_position = getpos('.')
  let match_line = match_position[1]
  let match_col = match_position[2]

  let remainder_of_line = strpart(getline('.'), match_col - 1)
  let expr = substitute(remainder_of_line, '^match \(.*\) {$', '\1', '')

  let ok_line      = match_line + 1
  let err_line     = match_line + 2
  let closing_line = match_line + 3

  if getline(ok_line) !~ '^\s*Ok(\(\k\+\)) => \1'
    return 0
  endif

  if getline(err_line) !~ '^\s*Err(\k\+) => return Err('
    return 0
  endif

  if search('^\s*}\ze', 'We', closing_line) <= 0
    return 0
  endif

  let end_position = getpos('.')

  call sj#ReplaceByPosition(match_position, end_position, expr.'?')
endfunction
