" File: autoload/w3m.vim
" Author: yuratomo (twitter @yusetomo)

let s:save_cpo = &cpo
set cpo&vim

let s:w3m_title = 'w3m'
let s:tmp_option = ''
let s:message_adjust = 20
let [s:TAG_START,s:TAG_END,s:TAG_BOTH,s:TAG_UNKNOWN] = range(4)

if has('win32')
    let s:abandon_error = ' 2> NUL'
el
    let s:abandon_error = ' 2> /dev/null'
en

call w3m#history#Load()

fun! w3m#BufWinEnter()
    call s:applySyntax()
endf

fun! w3m#BufWinLeave()
    call clearmatches()
endf

fun! w3m#CheckUnderCursor()
    let [cl,cc] = [ line('.'), col('.') ]
    let tstart = -1
    let tidx = 0
    for tag in b:tag_list
        if tag.line == cl && tag.col > cc
            let tstart = tidx - 1
            break
        en
        let tidx = tidx + 1
    endfor
    if tstart == -1
        return
    en

    let tidx = tstart
    while tidx >= 0
        if b:tag_list[tidx].line != cl
            if tidx > 0
                echo b:tag_list[tidx-1].attr
            en
            break
        en
        if b:tag_list[tidx].type != s:TAG_START
            let tidx -= 1
            continue
        en
        if has_key(b:tag_list[tidx].attr, 'href')
            echo b:tag_list[tidx].attr.href
            break
        en
        let tidx -= 1
    endwhile
endf

fun! w3m#ShowUsage()
    echo "[Usage] :W3m url"
    echo "example :W3m http://www.yahoo.co.jp"
endf

fun! w3m#ShowTitle()
    let cols = w3m#get_cols()
    " resolve title from cache
    if has_key(b:history[b:history_index], 'title')
        call s:message( strpart(b:history[b:history_index].title, 0, cols - s:message_adjust) )
        return
    en

    if exists('b:last_url')
        let title = "no title"
        for tag in b:tag_list
            if tag.type == s:TAG_START && tag.tagname ==? 'title_alt' && has_key(tag.attr, 'title')
                let title = tag.attr.title
                break
            en
        endfor
        call s:message( strpart(title, 0, cols - s:message_adjust) )
    en

    " cache title
    let b:history[b:history_index].title = title
endf

fun! w3m#ShowSourceAndHeader()
    if exists('b:last_url')
        let cmdline = join( [ g:w3m#command, s:tmp_option, g:w3m#option, '"' . b:last_url . '"' ], ' ')
        new
        exe     '%!'.substitute(cmdline, "-halfdump", "-dump_both", "")
    en
endf

fun! w3m#ShowDump()
    if exists('b:last_url')
        let cmdline = join( [ g:w3m#command, s:tmp_option, g:w3m#option, '"' . b:last_url . '"' ], ' ')
        new
        call setline(1, split(s:system(cmdline), '\n'))
    en
endf

fun! w3m#ShowExternalBrowser()
    if exists('g:w3m#external_browser') && exists('b:last_url')
        call s:system(g:w3m#external_browser . ' "' . b:last_url . '"')
    en
endf

fun! w3m#ShowURL()
    if exists('b:last_url')
        call s:message(b:last_url)
    en
endf

fun! w3m#CopyUrl(to)
    if exists('b:last_url')
        call setreg(a:to, b:last_url)
    en
endf

fun! w3m#Reload()
    if exists('b:last_url')
        call w3m#Open(g:w3m#OPEN_NORMAL, b:last_url)
    en
endf

fun! w3m#EditAddress()
    if exists('b:last_url')
        let url = input('url:', b:last_url)
        if url != ""
            call w3m#Open(g:w3m#OPEN_NORMAL, url)
            echo url
        en
    en
endf

fun! w3m#SetUserAgent(name, reload)
    let change = 0
    for item in g:w3m#user_agent_list
        if item.name == a:name
            let g:user_agent = item.agent
            let change = 1
            break
        en
    endfor
    if change == 1 && a:reload == 1
        call w3m#Reload()
    en
endf

fun! w3m#ListUserAgent(A, L, P)
    let items = []
    for item in g:w3m#user_agent_list
        if item.name =~ '^'.a:A
            call add(items, item.name)
        en
    endfor
    return items
endf

fun! w3m#MatchSearchStart(key)
    cno      <buffer> <CR> <CR>:call w3m#MatchSearchEnd()<CR>
    cno      <buffer> <ESC> <ESC>:call w3m#MatchSearchEnd()<CR>
    nno      <buffer> <ESC> <ESC>:call w3m#MatchSearchEnd()<CR>
    call feedkeys(a:key, 'n')
endf

fun! w3m#MatchSearchEnd()
    cno      <buffer> <CR> <CR>
    cno      <buffer> <ESC> <ESC>
    nno      <buffer> <ESC> <ESC>
    if exists('b:last_match_id') && b:last_match_id != -1
        try
            call matchdelete(b:last_match_id)
        catch
        endtry
    en
    let keyword = histget("search", -1)
    if keyword == '^.*$\n'
        return
    en
    let b:last_match_id = matchadd("Search", keyword)
endf

fun! w3m#ToggleSyntax()
    if b:enable_syntax == 0
        cal w3m#ChangeSyntaxOnOff(1)
    el
        cal w3m#ChangeSyntaxOnOff(0)
    en
endf

fun! w3m#ChangeSyntaxOnOff(mode)
    let b:enable_syntax = a:mode
    if a:mode == 0
        call clearmatches()
        call s:message("syntax off")
    el
        call s:applySyntax()
        call s:message("syntax on")
    en
endf

fun! w3m#ToggleUseCookie()
    if g:w3m#option_use_cookie == 0
        let g:w3m#option_use_cookie = 1
        call s:message("use_cookie on")
    el
        let g:w3m#option_use_cookie = 0
        call s:message("use_cookie off")
    en
endf

fun! w3m#Open(mode, ...)
    if len(a:000) == 0
        if exists('g:w3m#homepage')
            call w3m#Open(a:mode, g:w3m#homepage)
        el
            call w3m#ShowUsage()
        en
        return
    en
    if a:mode == g:w3m#OPEN_TAB
        -tabe   "g:w3m#OPEN_*的值是0，1，2，3, 不过 不用在意具体取值, 传参时还是传OPEN_XXX
    elseif a:mode == g:w3m#OPEN_SPLIT
        new
    elseif a:mode == g:w3m#OPEN_VSPLIT && has('vertsplit')
        vnew
    en

    call s:prepare_buffer()
    if b:history_index >= 0 && b:history_index < len(b:history)
        let b:history[b:history_index].curpos = [ line('.'), col('.') ]
    en

    "Load search engines and page filters
    call w3m#search_engine#Load()
    call w3m#page_filter#Load()

    "Is the search-engine specified?
    let use_filter = 0
    for se in g:w3m#search_engine_list
        if has_key(se, 'name') && has_key(se, 'url')
            if se.name == a:000[0]
                "preproc for search-engine
                if has_key(se, 'preproc')
                    call se.preproc()
                en
                let url = printf(se.url, join(a:000[1:], ' '))
                let use_filter = 1
                break
            en
        en
    endfor

    if use_filter == 0
        if s:isHttpURL(a:000[0])
            let url = s:normalizeUrl(a:000[0])
        el
            let url = printf(g:w3m#search_engine, join(a:000, ' '))
        en

        "Is the url match page-filter pattern?
        for se in g:w3m#page_filter_list
            if has_key(se, 'pattern')
                if match(url, se.pattern) != -1
                    "preproc for page-filter
                    if has_key(se, 'preproc')
                        call se.preproc()
                    en
                    let use_filter = 1
                    break
                en
            en
        endfor
    en

    "Is url include anchor?
    let anchor = ''
    let aidx = stridx(url, '#')
    if aidx >= 0
        let anchor = url[ aidx : ]
        let url = url[0 : aidx - 1 ]
    en

    "create command
    let cols = w3m#get_cols()
    let cmdline = s:create_command(url, cols)
    call s:message( strpart('open ' . url, 0, cols - s:message_adjust) )

    "postproc for filter
    if use_filter == 1
        if has_key(se, 'postproc')
            call se.postproc()
        en
    en

    "resolve charset from header and body(META)
    let b:charset = &encoding
    let header = split(s:system(substitute(cmdline, "-halfdump", "-dump_head", "")), '\n')
    if s:resolveCharset(header) == 0
        let body = split(s:system(substitute(cmdline, "-halfdump", "-dump_source", "")), '\n')
        let max_analize_line = 20
        if len(body) < max_analize_line
            let max_analize_line = len(body) - 1
        en
        call s:resolveCharset(body[0 : max_analize_line])
    en

    "exe     halfdump
    let outputs = split(s:neglectNeedlessTags(s:system(cmdline)), '\n')

    "do filter
    if use_filter == 1
        if has_key(se, 'filter')
            let outputs = se.filter(outputs)
        en
    en

    "add outputs to url-history
    if len(b:history) - 1 > b:history_index
        call remove(b:history, b:history_index+1, -1)
    en
    call add(b:history, {'url':url, 'outputs':outputs} )
    let b:history_index = len(b:history) - 1
    if b:history_index >= g:w3m#max_cache_page_num
        call remove(b:history, 0, 0)
        let b:history_index = len(b:history) - 1
    en

    call s:openCurrentHistory()

    "add global history
    let title = b:history[b:history_index].title
    call w3m#history#Regist(title, a:000)

    "move to anchor
    if anchor != ''
        call s:moveToAnchor(anchor)
    en
endf

fun! s:resolveCharset(header)
    let ret = 0
    let header_charset = filter(a:header, 'v:val =~ "charset="')
    if len(header_charset) > 0
        let b:charset = substitute(substitute(header_charset[0], '^.*\<charset=', '', ''), '[">].*$', '', '')
        let ret = 1
    en
    return ret
endf

fun! w3m#Back()
    if b:history_index <= 0
        return
    en
    let b:history[b:history_index].curpos = [ line('.'), col('.') ]
    let b:history_index -= 1
    call s:openCurrentHistory()
endf

fun! w3m#Forward()
    if b:history_index >= len(b:history) - 1
        return
    en
    let b:history[b:history_index].curpos = [ line('.'), col('.') ]
    let b:history_index += 1
    call s:openCurrentHistory()
endf

fun! w3m#PrevLink()
    let [cl,cc] = [ line('.'), col('.') ]
    let tstart = -1
    let tidx = 0
    for tag in b:tag_list
        if tag.type == s:TAG_START && s:is_tag_tabstop(tag)
            if tag.line == cl && tag.col >= cc -1
                break
            elseif tag.line > cl
                break
            el
                let tstart = tidx
            en
        en
        let tidx = tidx + 1
    endfor
    if tstart != -1
        call cursor(b:tag_list[tstart].line, b:tag_list[tstart].col)
    en
endf

fun! w3m#NextLink()
    let [cl,cc] = [ line('.'), col('.') ]
    let tstart = -1
    let tidx = 0
    for tag in b:tag_list
        if tag.type == s:TAG_START && s:is_tag_tabstop(tag)
            if tag.line == cl && tag.col > cc
                let tstart = tidx
                break
            elseif tag.line > cl
                let tstart = tidx
                break
            en
        en
        let tidx = tidx + 1
    endfor
    if tstart != -1
        call cursor(b:tag_list[tstart].line, b:tag_list[tstart].col)
    en
endf

fun! w3m#Click(shift, ctrl)
    let [cl,cc] = [ line('.'), col('.') ]
    let tstart = -1
    let tidx = 0
    for tag in b:tag_list
        if tag.line == cl && tag.col > cc
            let tstart = tidx - 1
            break
        en
        let tidx = tidx + 1
    endfor
    if tstart == -1
        call s:message('not process')
        return
    en
    call s:message('processing')

    let tidx = tstart
    while tidx >= 0
        if b:tag_list[tidx].line != cl
            break
        en
        if b:tag_list[tidx].type != s:TAG_START
            let tidx -= 1
            continue
        en
        let b:click_with_shift = a:shift
        let b:click_with_ctrl = a:ctrl
        let ret = s:dispatchTagProc(b:tag_list[tidx].tagname, tidx)
        if ret == 1
            break
        en
        let tidx -= 1
    endwhile

    call w3m#ShowTitle()
endf

fun! s:post(url, file)
    let s:tmp_option = '-post ' . a:file
    call w3m#Open(g:w3m#OPEN_NORMAL, a:url)
    let s:tmp_option = ''
    call s:message('post ok')
endf

fun! s:openCurrentHistory()
    setlocal modifiable
    call s:message('analize output')
    let b:display_lines = s:analizeOutputs(b:history[b:history_index].outputs)
    let b:last_url = b:history[b:history_index].url
    call clearmatches()
    % delete _
    call setline(1, b:display_lines)
    call w3m#ShowTitle()
    call s:applySyntax()
    if has_key(b:history[b:history_index], 'curpos')
        let [cl,cc] = b:history[b:history_index].curpos
        call cursor(cl, cc)
    en
    " setlocal ft=w3m bt=nofile noswf nomodifiable nowrap hidden nolist
    setlocal ft=w3m bt=nofile noswf modifiable nowrap hidden nolist
endf

fun! s:analizeOutputs(output_lines)
    let display_lines = []
    let b:tag_list = []
    let b:anchor_list = []
    let b:form_list = []

    let cline = 1
    let tnum  = 0
    for line in a:output_lines
        let analaized_line = ''
        let [lidx, ltidx, gtidx] = [ 0, -1, -1 ]
        let line_anchor_list = []
        while 1
            let ltidx = stridx(line, '<', lidx)
            if ltidx >= 0
                let analaized_line .= s:decordeEntRef(strpart(line, lidx, ltidx-lidx))
                let ccol = strlen(analaized_line) + 1
                let lidx = ltidx + 1
                let gtidx = stridx(line, '>', lidx)
                if gtidx >= 0
                    let ctag = strpart(line, ltidx, gtidx-ltidx+1)
                    let type = s:resolvTagType(ctag)
                    let attr = {}
                    let tname = s:analizeTag(ctag, attr)
                    let item = {
                            \ 'line':cline,
                            \ 'col':ccol,
                            \ 'type':type,
                            \ 'tagname':tname,
                            \ 'attr':attr,
                            \ 'evalue':'',
                            \ 'edited':0,
                            \ 'echecked':0
                            \ }
                    call add(b:tag_list, item)
                    if tname == 'a'
                        " Assume: All anchors start and stop on the same line
                        if type == s:TAG_START
                            " A link/anchor has been found
                            call add( line_anchor_list, {"startCol":ccol,"endCol":ccol,"line":cline,"attr":attr})
                        el
                            let n = len(line_anchor_list) - 1
                            "let line_anchor_list[n]["endCol"] = ccol
                            " echo "attr: ".attr
                            " sleep
                            let line_anchor_item = get(line_anchor_list, n, 0)
                            if type(line_anchor_item) == 4
                                let line_anchor_item["endCol"] = ccol
                            en
                            unlet line_anchor_item
                        end
                    en
                    let tnum += 1
                    if stridx(tname,'input') == 0
                        call add(b:form_list, item)
                    en
                    let lidx = gtidx + 1
                el
                    let analaized_line .= s:decordeEntRef(strpart(line, lidx))
                    break
                en
            el
                let analaized_line .= s:decordeEntRef(strpart(line, lidx))
                break
            en
        endwhile
        call add(display_lines, analaized_line)
        call add(b:anchor_list, line_anchor_list)
        let cline += 1
    endfor
    return display_lines
endf

fun! s:resolvTagType(tag)
    if stridx(a:tag, '<') == 0
        if stridx(a:tag, '/>') >= 0 && match(a:tag, '=\a') == -1
            return s:TAG_BOTH
        elseif stridx(a:tag, '</') == 0
            return s:TAG_END
        el
            return s:TAG_START
        en
    en
    return s:TAG_UNKNOWN
endf

fun! s:analizeTag(tag, attr)
    let tagname_e = stridx(a:tag, ' ') - 1
    let taglen = strlen(a:tag)
    if tagname_e < 0
        if a:tag[1:1] == '/'
            return tolower(strpart(a:tag, 2, taglen-3))
        el
            return tolower(strpart(a:tag, 1, taglen-2))
        en
    en

    let tagname = tolower(strpart(a:tag, 1, tagname_e))
    let idx = tagname_e + 2
    while 1
        if idx >= taglen
            break
        en

        let na = stridx(a:tag, ' ', idx)
        let eq = stridx(a:tag, '=', idx)
        if eq == -1 || eq > na
            if na == -1
                if eq == -1
                    let key = strpart(a:tag, idx, taglen-idx-1)
                    if key != ""
                        let a:attr[tolower(key)] = ''
                    en
                    break
                en
                let na = taglen - 1
            el " no value key
                let key = strpart(a:tag, idx, na-idx)
                if key != ""
                    let a:attr[tolower(key)] = ''
                en
                let idx = na + 1
                continue
            en
        en

        let vs = eq+1
        if a:tag[vs] == '"' || a:tag[vs] == "'"
            let ee = stridx(a:tag, a:tag[vs], vs+1) " end quate
            let vs += 1
            let ve = ee - 1
            let na = ee + 1
        el
            let ve = na - 1
        en
        let ks = idx
        let ke = eq - 1

        let keyname = strpart(a:tag, ks, ke-ks+1)
        if strlen(keyname) > 0
            let a:attr[tolower(keyname)] = s:decordeEntRef(strpart(a:tag, vs, ve-vs+1))
        en
        let idx = na + 1
    endwhile

    return tagname
endf

fun! s:prepare_buffer()
    if !exists('b:w3m_bufname')
        let id = 1
        while buflisted(s:w3m_title.'-'.id)
            let id += 1
        endwhile
        let bufname = s:w3m_title.'-'.id
        silent edit `=bufname`

        let b:w3m_bufname = s:w3m_title.'-'.id
        let b:last_url = ''
        let b:history_index = 0
        let b:history = []
        let b:display_lines = []
        let b:tag_list = []
        let b:anchor_list = []
        let b:form_list = []
        let b:click_with_shift = 0
        let b:click_with_ctrl = 0
        let b:last_match_id = -1
        let b:enable_syntax = 1

        call s:keymap()
        call s:default_highligh()

        augroup w3m
            au BufWinEnter <buffer> silent! call w3m#BufWinEnter()
            au BufWinLeave <buffer> silent! call w3m#BufWinLeave()
        augroup END
    en
endf

fun! s:keymap()
    nno      <buffer><Plug>(w3m-shift-ctrl-click)  :<C-u>call w3m#Click(1, 1)<CR>
    nno      <buffer><Plug>(w3m-click)         :<C-u>call w3m#Click(0, 0)<CR>
    nno      <buffer><Plug>(w3m-shift-click)   :<C-u>call w3m#Click(1, 0)<CR>
    nno      <buffer><Plug>(w3m-address-bar)   :<C-u>call w3m#EditAddress()<CR>
    nno      <buffer><Plug>(w3m-next-link)     :<C-u>call w3m#NextLink()<CR>
    nno      <buffer><Plug>(w3m-prev-link)     :<C-u>call w3m#PrevLink()<CR>
    nno      <buffer><Plug>(w3m-back)          :<C-u>call w3m#Back()<CR>
    nno      <buffer><Plug>(w3m-forward)       :<C-u>call w3m#Forward()<CR>
    nno      <buffer><Plug>(w3m-show-link)     :<C-u>call w3m#CheckUnderCursor()<CR>
    nno      <buffer><Plug>(w3m-show-title)    :<C-u>call w3m#ShowTitle()<CR>
    nno      <buffer><Plug>(w3m-search-start)  :<C-u>call w3m#MatchSearchStart('/')<CR>
    nno      <buffer><Plug>(w3m-search-end)    :<C-u>call w3m#MatchSearchEnd()<CR>
    nno      <buffer><Plug>(w3m-hit-a-hint)    :<C-u>call w3m#HitAHintStart()<CR>
    nno      <buffer><Plug>(w3m-syntax-on)     :<C-u>call w3m#ChangeSyntaxOnOff(1)<CR>
    nno      <buffer><Plug>(w3m-syntax-off)    :<C-u>call w3m#ChangeSyntaxOnOff(0)<CR>
    nno      <buffer><Plug>(w3m-toggle-syntax) :<C-u>call w3m#ToggleSyntax()<CR>
    nno      <buffer><Plug>(w3m-toggle-use-cookie) :<C-u>call w3m#ToggleUseCookie()<CR>

    if !exists('g:w3m#disable_default_keymap') || g:w3m#disable_default_keymap == 0
        nmap <buffer><LeftMouse> <LeftMouse><Plug>(w3m-click)
        nmap <buffer><CR>        <Plug>(w3m-click)
        nmap <buffer><S-CR>      <Plug>(w3m-shift-click)
        nmap <buffer><C-S-CR>    <Plug>(w3m-shift-ctrl-click)
        " nmap <buffer><TAB>       <Plug>(w3m-next-link)
        " nmap <buffer><S-TAB>     <Plug>(w3m-prev-link)
        nmap <buffer><C-n>       <Plug>(w3m-next-link)
        nmap <buffer><C-p>       <Plug>(w3m-prev-link)
        nmap <buffer><BS>        <Plug>(w3m-back)
        " nmap <buffer><C-o>       <Plug>(w3m-back)
        " nmap <buffer><A-LEFT>    <Plug>(w3m-back)
        nmap <buffer><A-RIGHT>   <Plug>(w3m-forward)
        nmap <buffer>s           <Plug>(w3m-toggle-syntax)
        " nmap <buffer>c           <Plug>(w3m-toggle-use-cookie)
        nmap <buffer>=           <Plug>(w3m-show-link)
        nmap <buffer>/           <Plug>(w3m-search-start)
        nmap <buffer>*           *<Plug>(w3m-search-end)
        " nmap <buffer>#           #<Plug>(w3m-search-end)
        nmap <buffer><m-d>       <Plug>(w3m-address-bar)
        " exe 'nmap <buffer>' . g:w3m#hit_a_hint_key . ' <Plug>(w3m-hit-a-hint)'
    en
endf

fun! s:default_highligh()
    if !hlexists('w3mBold')
        hi w3mBold gui=bold
    en
    if !hlexists('w3mUnderline')
        hi w3mUnderline gui=underline
    en
    if !hlexists('w3mInput')
        highlight! link w3mInput String
    en
    if !hlexists('w3mSubmit')
        highlight! link w3mSubmit Special
    en
    if !hlexists('w3mLink')
        highlight! link w3mLink Function
    en
    if !hlexists('w3mAnchor')
        highlight! link w3mAnchor Label
    en
    if !hlexists('w3mLinkHover')
        highlight! link w3mLinkHover SpecialKey
    en
    if !hlexists('w3mHitAHint')
        highlight! link w3mHitAHint Question
    en
endf

fun! s:applySyntax()
    if b:enable_syntax == 0
        return
    en
    let link_s = -1
    let bold_s = -1
    let underline_s = -1
    let input_s = -1
    let input_highlight = ""
    let link_anchor = 0
    for tag in b:tag_list
        if link_s == -1 && tag.tagname ==? 'a' && tag.type == s:TAG_START
            if tag.col > 0
                let link_s = tag.col -1
            el
                let link_s = 0
            en
            if has_key(tag.attr, 'href') && tag.attr.href[0] == '#'
                let link_anchor = 1
            en
        elseif link_s != -1 && tag.tagname ==? 'a' && tag.type == s:TAG_END
            let link_e = tag.col
            if link_anchor == 1
                call matchadd('w3mAnchor', '\%>'.link_s.'c\%<'.link_e.'c\%'.tag.line.'l')
            el
                call matchadd('w3mLink', '\%>'.link_s.'c\%<'.link_e.'c\%'.tag.line.'l')
            en
            let link_anchor = 0
            let link_s = -1

        elseif bold_s == -1 && tag.tagname ==? 'b' && tag.type == s:TAG_START
            if tag.col > 0
                let bold_s = tag.col -1
            el
                let bold_s = 0
            en
        elseif bold_s != -1 && tag.tagname ==? 'b' && tag.type == s:TAG_END
            let bold_e = tag.col
            call matchadd('w3mBold', '\%>'.bold_s.'c\%<'.bold_e.'c\%'.tag.line.'l')
            let bold_s = -1

        elseif underline_s == -1 && tag.tagname ==? 'u' && tag.type == s:TAG_START
            if tag.col > 0
                let underline_s = tag.col -1
            el
                let underline_s = 0
            en
        elseif underline_s != -1 && tag.tagname ==? 'u' && tag.type == s:TAG_END
            let underline_e = tag.col
            call matchadd('w3mUnderline', '\%>'.underline_s.'c\%<'.underline_e.'c\%'.tag.line.'l')
            let underline_s = -1

        elseif input_s == -1 && tag.tagname ==? 'input_alt' && tag.type == s:TAG_START
            if s:is_tag_input_image_submit(tag)
                let input_highlight = 'w3mSubmit'
            el
                let input_highlight = 'w3mInput'
            en
            if tag.col > 0
                let input_s = tag.col -1
            el
                let input_s = 0
            en
        elseif input_s != -1 && stridx(tag.tagname, 'input') == 0 && tag.type == s:TAG_END
            let input_e = tag.col
            call matchadd(input_highlight, '\%>'.input_s.'c\%<'.input_e.'c\%'.tag.line.'l')
            let input_s = -1
        en
    endfor

endf

" apply hover-links function
if exists('g:w3m#set_hover_on') && g:w3m#set_hover_on > 0
    let g:w3m#set_hover_on = 1
    if has("autocmd")
        if g:w3m#hover_delay_time == 0
            " everytime the cursor moves in the buffer
            " normal mode is forcesd by default, so only check normal mode
            au! CursorMoved w3m-*  call s:applyHoverHighlight()
        el
            au! CursorMoved w3m-*  call s:delayHoverHighlight()
        en
    el
        unlet g:w3m#set_hover_on
    en
    fun! s:delayHoverHighlight()
        if !exists('g:w3m#updatetime_backup')
            let g:w3m#updatetime_backup = &updatetime
            let &updatetime = g:w3m#hover_delay_time
            au! CursorHold w3m-*  call s:applyHoverHighlight()
        en
    endf
    fun! s:applyHoverHighlight()
        if !exists('g:w3m#set_hover_on') || g:w3m#set_hover_on < 1
            " hover-links is turned OFF
            return
        en
        let [cline,ccol] = [ line('.'), col('.') ]
        if exists("b:match_hover_anchor") && b:match_hover_anchor.line == cline && b:match_hover_anchor.startCol <=  ccol && b:match_hover_anchor.endCol > ccol
            " the link under the cursor has not changed
            return
        en
        if cline >= len(b:anchor_list)
            return
        en
        " loop through all anchors on this line
        for anchor in b:anchor_list[cline - 1]
            if anchor.startCol <= ccol && anchor.endCol > ccol
                " a match is found
                let a_found = anchor
                break
            en
            if anchor.startCol > ccol
                " we've gone to far
                break
            en
        endfor
        if exists('b:match_hover_id')
            " restore color
            silent! call matchdelete(b:match_hover_id)
            unlet b:match_hover_id
            unlet b:match_hover_anchor
        en
        if exists('a_found')
            let b:match_hover_anchor = a_found
            let tstart = b:match_hover_anchor.startCol - 1
            let tend   = b:match_hover_anchor.endCol
            let b:match_hover_id = matchadd('w3mLinkHover', '\%>'.tstart.'c\%<'.tend.'c\%'.cline.'l')
        en
        if exists('g:w3m#updatetime_backup')
            let &updatetime = g:w3m#updatetime_backup
            au! CursorHold w3m-*
            unlet g:w3m#updatetime_backup
        en
    endf
en

fun! s:escapeSyntax(str)
    return escape(a:str, '~"\|*-[]')
endf

fun! s:dispatchTagProc(tagname, tidx)
    let ret = 0
    if a:tagname ==? 'a'
        let ret = s:tag_a(a:tidx)
    elseif stridx(a:tagname, 'input') == 0
        let ret = s:tag_input(a:tidx)
    en
    return ret
endf

fun! s:tag_a(tidx)
    if has_key(b:tag_list[a:tidx].attr,'href')
        let url = s:resolveUrl(b:tag_list[a:tidx].attr.href)
        if s:is_download_target(url)
            call s:downloadFile(url)
        elseif s:is_anchor(url)
            call s:moveToAnchor(url)
        el
            let open_mode = g:w3m#OPEN_NORMAL
            let s_orientation = b:click_with_shift + b:click_with_ctrl
            if s_orientation == 1
                let open_mode = g:w3m#OPEN_SPLIT
            en
            if s_orientation == 2
                let open_mode = g:w3m#OPEN_VSPLIT
            en

            if s:isHttpURL(url)
                call w3m#Open(open_mode, url)
            el
                call w3m#Open(open_mode, 'local', url)
            en
        en
        return 1
    en
    return 0
endf

fun! s:tag_input(tidx)
    let url = ''
    " find form
    if !has_key(b:tag_list[a:tidx].attr,'type')
        return
    en
    let type = b:tag_list[a:tidx].attr.type

    try
        call s:tag_input_{tolower(type)}(a:tidx)
    catch /^Vim\%((\a\+)\)\=:E117/
    endtry

    return 1
endf

fun! s:tag_input_image(tidx)
    if has_key(b:tag_list[a:tidx].attr,'value') && b:tag_list[a:tidx].attr.value ==? 'submit'
        call s:tag_input_submit(a:tidx)
    en
endf

fun! s:tag_input_submit(tidx)
    let idx = a:tidx - 1
    let action = 'GET'
    let fid = 0
    while idx >= 0
        if b:tag_list[idx].type == s:TAG_START && stridx(b:tag_list[idx].tagname, 'form') == 0
         if has_key(b:tag_list[idx].attr,'action')
             let url = s:resolveUrl(b:tag_list[idx].attr.action)
             if has_key(b:tag_list[idx].attr,'method')
                 let action = b:tag_list[idx].attr.method
             en
             if has_key(b:tag_list[idx].attr,'fid')
                 let fid = b:tag_list[idx].attr.fid
             en
             break
         en
     en
     let idx -= 1
    endwhile

    if url != ''
        if action ==? 'GET'
            let query = w3m#buildQueryString(fid, a:tidx, 1)
            call w3m#Open(g:w3m#OPEN_NORMAL, url . query)
        elseif action ==? 'POST'
            let file = w3m#generatePostFile(fid, a:tidx)
            call s:post(url, file)
            call delete(file)
        el
            call s:message(toupper(action) . ' is not support')
        en
    en
endf

fun! s:tag_input_text(tidx)
    redraw
    if b:tag_list[a:tidx].edited == 0
        if has_key(b:tag_list[a:tidx].attr, 'value')
            let value = b:tag_list[a:tidx].attr.value
        el
            let value = ''
        en
    el
        let value = b:tag_list[a:tidx].evalue
    en
    let b:tag_list[a:tidx].evalue = input('input:', value)
    let b:tag_list[a:tidx].edited = 1
    call s:applyEditedInputValues()
endf

fun! s:tag_input_textarea(tidx)
    call s:tag_input_text(a:tidx)
endf

fun! s:tag_input_password(tidx)
    redraw
    if b:tag_list[a:tidx].edited == 0
        let value = b:tag_list[a:tidx].attr.value
    el
        let value = b:tag_list[a:tidx].evalue
    en
    let b:tag_list[a:tidx].evalue = input('input password:', value)
    let b:tag_list[a:tidx].edited = 1
    call s:applyEditedInputValues()
endf

fun! s:tag_input_radio(tidx)
    redraw
    " ¼Ì¯¶nameÌecheckedðZbg
    for item in b:form_list
        if has_key(item.attr, 'type') && item.attr.type ==? 'radio'
            let item.edited = 1
            let item.echecked = 0
        en
    endfor

    let b:tag_list[a:tidx].echecked = 1
    if has_key(b:tag_list[a:tidx].attr, 'value')
        let value = b:tag_list[a:tidx].attr.value
    el
        let value = ''
    en
    let b:tag_list[a:tidx].evalue = value
    call s:applyEditedInputValues()
endf

fun! s:tag_input_checkbox(tidx)
    redraw
    if b:tag_list[a:tidx].edited == 1
        if b:tag_list[a:tidx].echecked == 1
            let b:tag_list[a:tidx].echecked = 0
        el
            let b:tag_list[a:tidx].echecked = 1
        en
    el
        let b:tag_list[a:tidx].edited = 1
        if has_key(b:tag_list[a:tidx], 'checked')
            let b:tag_list[a:tidx].echecked = 0
        el
            let b:tag_list[a:tidx].echecked = 1
        en
    en
    if has_key(b:tag_list[a:tidx].attr, 'value')
        let value = b:tag_list[a:tidx].attr.value
    el
        let value = ''
    en
    let b:tag_list[a:tidx].evalue = value
    call s:applyEditedInputValues()
endf

fun! s:tag_input_reset(tidx)
    for item in b:form_list
        if s:is_editable_tag(item)
            let item.evalue = ''
            let item.edited = 0
        en
    endfor
    call s:applyEditedInputValues()
    call s:message('reset form data')
endf

fun! s:select_options(selectnumber)
    let options = []
    let stage = 0
    for tag in b:tag_list
        if stage == 0 && tag.type == s:TAG_START && tag.tagname ==? 'select_int' && has_key(tag.attr, 'selectnumber') && tag.attr.selectnumber == a:selectnumber
            let stage = 1
        elseif stage == 1 && tag.type == s:TAG_START && tag.tagname ==? 'option_int'
            call add(options, tag.attr)
        elseif stage == 1 && tag.tagname ==? 'select_int'
            break
        elseif stage == 1 && tag.type == s:TAG_START && tag.tagname ==? 'select_int'
            break
        en
    endfor
    return options
endf

fun w3m#select_option_list(A,L,P)
    let items = []
    for attr in b:options
        if attr.label =~ '^'.a:A
            call add(items, attr.label)
        en
    endfor
    return items
endfun

fun! s:tag_input_select(tidx)
    let b:options = s:select_options(b:tag_list[a:tidx].attr.selectnumber)
    redraw
    let wmde = &wildmode
    let &wildmode = "full"
    let label = input("select option:", "", "customlist,w3m#select_option_list")
    let &wildmode = wmde
    for attr in b:options
        if attr.label == label
            let b:tag_list[a:tidx].evalue = attr.value
            let b:tag_list[a:tidx].elabel = attr.label
            let b:tag_list[a:tidx].edited = 1
            break
        en
    endfor
    call s:applyEditedInputValues()
endf

" ---

fun! s:create_command(url, cols)
    let command_list = [ g:w3m#command, s:tmp_option, g:w3m#option, '-cols', a:cols]

    if g:w3m#option_use_cookie != -1
        call add(command_list, '-o use_cookie=' . g:w3m#option_use_cookie)
    en
    if g:w3m#option_accept_cookie != -1
        call add(command_list, '-o accept_cookie=' . g:w3m#option_accept_cookie)
    en
    if g:w3m#option_accept_bad_cookie != -1
        call add(command_list, '-o accept_bad_cookie=' . g:w3m#option_accept_bad_cookie)
    en
    if g:user_agent != ''
        call add(command_list, '-o user_agent="' . g:user_agent . '"')
    en

    call add(command_list, '"' . a:url . '"')
    let cmdline = join(command_list, ' ') . s:abandon_error
    return cmdline
endf

fun! s:resolveUrl(url)
    if s:isHttpURL(a:url)
        return s:decordeEntRef(a:url)
    elseif s:is_anchor(a:url)
        return a:url
    el
        if a:url[0] == '/'
            let base = strlen(b:last_url) - 1
            let tmp = stridx(b:last_url, '/')
            if tmp != -1
                let tmp = stridx(b:last_url, '/', tmp+1)
                if tmp != -1
                    let tmp = stridx(b:last_url, '/', tmp+1)
                    if tmp != -1
                        let base = tmp - 1
                    en
                en
            en
        el
            let base = strridx(b:last_url, '/')
        en
        let url = strpart(b:last_url, 0, base+1)
        return url . s:decordeEntRef(a:url)
    en
endf

fun! w3m#buildQueryString(fid, tidx, is_encode)
    let query = ''
    let first = 1
    for item in b:form_list
        if has_key(item.attr,'name') && item.attr.name != ''
            if !has_key(item.attr,'fid') || item.attr.fid != a:fid
                continue
            en
            if has_key(item.attr,'type')
                "if item.attr.type == 'submit' && has_key(item.attr, 'name') && item.attr.name != b:tag_list[a:tidx].attr.name
                if item.attr.type == 'submit'
                    continue
                elseif item.attr.type == 'radio' || item.attr.type == 'checkbox'
                    if item.edited == 1
                        if item.echecked == 0
                            continue
                        en
                    el
                        if !has_key(item.attr, 'checked')
                            continue
                        en
                    en
                elseif item.attr.type == 'select'
                    if item.edited == 0
                        let options = s:select_options(item.attr.selectnumber)
                        for option in options
                            if has_key(option, 'selected')
                                let item.attr.value = option.value
                                break
                            en
                        endfor
                    en
                en
            en

            if first == 1
                let query .= '?'
                let first = 0
            el
                let query .= '&'
            en
            if item.edited == 0
                if has_key(item.attr,'value')
                    let value = item.attr.value
                el
                    let value = ''
                en
            el
                let value = item.evalue
            en
            if a:is_encode == 1
                let query .= item.attr.name . '=' . s:encodeUrl(value)
            el
                let query .= item.attr.name . '=' . value
            en
        en
    endfor
    return query
endf

fun! w3m#generatePostFile(fid, tidx)
    let tmp_file = tempname()
    let items = w3m#buildQueryString(a:fid, a:tidx, 0)[1:] . '&'
    call writefile([ items ], tmp_file)
    return tmp_file
endf

fun! s:applyEditedInputValues()
    for item in b:form_list
        if s:is_editable_tag(item)
            if item.edited == 0
                if has_key(item.attr,'value')
                    let value = item.attr.value
                el
                    if item.attr.type == 'select'
                        let options = s:select_options(item.attr.selectnumber)
                        for option in options
                            if has_key(option, 'selected')
                                let value = option.label
                                break
                            en
                        endfor
                    el
                        let value = ''
                    en
                en
            el
                if has_key(item,'elabel')
                    let value = item.elabel
                el
                    let value = item.evalue
                en
            en
            let line = getline(item.line)
            let s = stridx(line, '[')
            if s >= 0
                let e = stridx(line, ']')
                if e >= 0
                    let i = s+strlen(value) + 1
                    while i < e
                        let value .= ' '
                        let i += 1
                    endwhile
                en
            en
            let value = strpart(value, 0, e - s -1)
            let line = strpart(line, 0, item.col-1) . value . strpart(line, item.col+strlen(value)-1)
            setlocal modifiable
            call setline(item.line, line)
            " setlocal nomodifiable

        elseif s:is_radio_or_checkbox(item)
            if item.edited == 1
                if item.echecked == 1
                    let value = '*'
                el
                    let value = ' '
                en
            el
                if has_key(item.attr, 'checked')
                    let value = '*'
                el
                    let value = ' '
                en
            en
            let line = getline(item.line)
            let line = strpart(line, 0, item.col-1) . value . strpart(line, item.col)
            setlocal modifiable
            call setline(item.line, line)
            " setlocal nomodifiable

        en
    endfor
endf

fun! w3m#HitAHintStart()
    if !exists('b:tag_list')
        return
    en
    let index = 0
    for item in b:tag_list
        if item.tagname ==? 'a' && item.type == s:TAG_START && item.line >= line('w0')
            let link_s = item.col-1
            let link_e = item.col+strlen(index)
            let line = getline(item.line)
            let line = strpart(line, 0, link_s) . '@' . index . strpart(line, link_e)
            setlocal modifiable
            call setline(item.line, line)
            " setlocal nomodifiable
            let link_e = link_e + 1
            call matchadd('w3mHitAHint', '\%>'.link_s.'c\%<'.link_e.'c\%'.item.line.'l')
            let index = index + 1
        en
        if item.line >= line('w$')
            break
        en
    endfor
    cno      <buffer> <CR> <CR>:call w3m#Click(0,0)<CR>:call w3m#HitAHintEnd()<CR>
    cno      <buffer> <ESC> <ESC>:call w3m#HitAHintEnd()<CR>
    nno      <buffer> <ESC> <ESC>:call w3m#HitAHintEnd()<CR>
    call feedkeys('/@', 'n')
endf

fun! w3m#HitAHintEnd()
    cno      <buffer> <CR> <CR>
    cno      <buffer> <ESC> <ESC>
    nno      <buffer> <ESC> <ESC>
    call s:applySyntax()
    for item in b:tag_list
        if item.tagname ==? 'a' && item.type == s:TAG_START && item.line >= line('w0')
            let line = b:display_lines[item.line-1]
            setlocal modifiable
            call setline(item.line, line)
            " setlocal nomodifiable
        en
        if item.line >= line('w$')
            break
        en
    endfor
endf

fun! s:encodeUrl(str)
    if &encoding ==? b:charset
        let utf8str = a:str
    el
        let utf8str = iconv(a:str, &encoding, b:charset)
    en
    let retval = substitute(utf8str,  '[^- *.0-9A-Za-z]', '\=s:ch2hex(submatch(0))', 'g')
    let retval = substitute(retval, ' ', '%20', 'g')
    return retval
endf

fun! s:ch2hex(ch)
    let result = ''
    let i = 0
    while i < strlen(a:ch)
        let hex = s:nr2hex(char2nr(a:ch[i]))
        let result = result . '%' . (strlen(hex) < 2 ? '0' : '') . hex
        let i = i + 1
    endwhile
    return result
endf

fun! s:nr2hex(nr)
    let n = a:nr
    let r = ""
    while 1
        let r = '0123456789ABCDEF'[n % 16] . r
        let n = n / 16
        if n == 0
            break
        en
    endwhile
    return r
endf

fun! s:isHttpURL(str)
    if stridx(a:str, 'http://') == 0 || stridx(a:str, 'https://') == 0
        return 1
    en
    return 0
endf

fun! s:normalizeUrl(url)
    let url = a:url
    let s1 = stridx(a:url, '/')
    let s2 = stridx(a:url, '/', s1+1)
    let s3 = stridx(a:url, '/', s2+1)
    if s3 == -1
        let url .= '/'
    en
    return url
endf

fun! s:neglectNeedlessTags(output)
    return substitute(a:output,'<[/]\{0,1\}\(_symbol\|_id\|intenal\|pre_int\|img_alt\|nobr\).\{-\}>','','g')
endf

fun! s:decordeEntRef(str)
    let str = a:str
    let str = substitute(str, '&quot;',   '"', 'g')
    let str = substitute(str, '&#40;',    '(', 'g')
    let str = substitute(str, '&#41;',    ')', 'g')
    let str = substitute(str, '&laquo;',  'á', 'g')
    let str = substitute(str, '&raquo;',  'â', 'g')
    let str = substitute(str, '&lt;',     '<', 'g')
    let str = substitute(str, '&gt;',     '>', 'g')
    let str = substitute(str, '&amp;',    '\&','g')
    let str = substitute(str, '&yen;',    '\\','g')
    let str = substitute(str, '&cent;',   '￠','g')
    let str = substitute(str, '&copy;',   'c', 'g')
    let str = substitute(str, '&middot;', '・','g')
    let str = substitute(str, '&mdash;',  '-','g')
    let str = substitute(str, '&ndash;',  '-','g')
    let str = substitute(str, '&apos;',   "'", 'g')
    let str = substitute(str, '&#x2014;',   '-', 'g')
    let str = substitute(str, '&#x203A;',   '>', 'g')
    return    substitute(str, '&nbsp;',   ' ', 'g')
endf

fun! s:message(msg)
    redraw
    if a:msg != ''
        echom 'w3m: ' . a:msg
    en
endf

fun! s:system(string)
    if exists('*vimproc#system()') && g:w3m#disable_vimproc == 0
        return vimproc#system(a:string)
    el
        return system(a:string)
    en
endf

fun! s:downloadFile(url)
    if executable(g:w3m#wget_command)
        let output_dir = input("save dir: ", expand("$HOME"), "dir")
        call s:message('download ' . a:url)
        echo s:system(g:w3m#wget_command . ' -P "' . output_dir . '" ' . a:url)
    en
endf

fun! s:is_download_target(href)
    let dot = strridx(a:href, '.')
    if dot == -1
        return 0
    en
    let ext = strpart(a:href, dot+1)
    if index(g:w3m#download_ext, tolower(ext)) >= 0
        return 1
    en
    return 0
endf

fun! s:moveToAnchor(href)
    let aname = a:href[1:]
    for tag in b:tag_list
        if has_key(tag.attr, 'name') && tag.attr.name ==? aname
            call cursor(tag.line, tag.col)
            break
        en
    endfor
endf

fun! s:is_anchor(href)
    if a:href[0] ==? '#'
        return 1
    en
    return 0
endf

fun! s:is_tag_input_image_submit(tag)
    if a:tag.tagname ==? 'input_alt'
        if has_key(a:tag.attr,'type') && a:tag.attr.type ==? 'image'
            if has_key(a:tag.attr,'value') && a:tag.attr.value ==? 'submit'
                return 1
            en
        en
    en
    return 0
endf

fun! s:is_editable_tag(tag)
    if has_key(a:tag.attr,'name') && has_key(a:tag.attr,'type') && a:tag.tagname ==? 'input_alt'
        if a:tag.attr.type ==? 'text' || a:tag.attr.type ==? 'textarea' || a:tag.attr.type ==? 'select'
            return 1
        en
    en
    return 0
endf

fun! s:is_radio_or_checkbox(tag)
    if has_key(a:tag.attr,'name') && has_key(a:tag.attr,'type') && a:tag.tagname ==? 'input_alt'
        if a:tag.attr.type ==? 'radio' || a:tag.attr.type ==? 'checkbox'
            return 1
        en
    en
    return 0
endf

fun! s:is_tag_tabstop(tag)
    if a:tag.tagname ==? 'a' || a:tag.tagname ==? 'input_alt'
        return 1
    en
    return 0
endf

" Format to a more readable 80 columns by default
fun! w3m#get_cols() abort
    let l:cols = winwidth(1) - &numberwidth
    if !exists('g:w3m#allow_long_lines')
        if l:cols > 80
            let l:cols = 80
        en
    en
    return l:cols
endf

let &cpo = s:save_cpo
unlet s:save_cpo
