" File: syntax/w3m.vim
" Author: yuratomo (twitter @yusetomo)

if  exists("b:current_syntax")
    finish
endif

" some functional highlight group are defined in
    " /home/wf/.local/share/nvim/PL/w3m/autoload/w3m.vim
    " e.g.
    " call matchadd('w3mUnderline', '\%>'.underline_s.'c\%<'.underline_e.'c\%'.tag.line.'l')

" 这里的, just for good looking.

" syn match w3mMark   /[\*\+\-\#="]/
syn match   w3mMark   /[-*+#="]/
syn match   w3mNumber /^ *[0-9]\+\./

syn match w3mDate /\v<[0-9]{1,4}年[0-9]{1,2}月[0-9]{1,2}日/
syn match w3mDate /\v<[0-9]{1,4}-[0-9]{1,2}-[0-9]{1,2}/
syn match w3mBracket1 /\v\[\_.{-0,30}]/
                       " \_.
                       " Matches any single character or end-of-line.
syn match w3mUrl contained
    \ "\vhttps?://[[:alnum:]][-[:alnum:]]*[[:alnum:]]?(\.[[:alnum:]][-[:alnum:]]*[[:alnum:]]?)*\.[[:alpha:]][-[:alnum:]]*[[:alpha:]]?(:\d+)?(/[^[:space:]]*)?$"
syn match w3mUrl "http[s]\=://\S*"

" hi default link w3mMark Function
hi default link w3mMark Ignore
hi default link w3mNumber Number
hi default link w3mDate Define
hi default link w3mBracket1 Macro
hi default link w3mUrl Comment
hi default link w3mTitle Comment

let b:current_syntax = 'w3m'
