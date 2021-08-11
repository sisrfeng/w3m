if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

command! -buffer -nargs=* CopyUrl :call w3m#CopyUrl('*')
command! -buffer -nargs=* Reload :call w3m#Reload()
command! -buffer -nargs=* AddressBar :call w3m#EditAddress()
command! -buffer -nargs=* ShowTitle :call w3m#ShowTitle()
command! -buffer -nargs=* ShowExtenalBrowser :call w3m#ShowExternalBrowser()
command! -buffer -nargs=* ShowSource :call w3m#ShowSourceAndHeader()
command! -buffer -nargs=* ShowDump :call w3m#ShowDump()
command! -buffer -nargs=* Close :bd
command! -buffer -nargs=* SyntaxOff :call w3m#ChangeSyntaxOnOff(0)
command! -buffer -nargs=* SyntaxOn :call w3m#ChangeSyntaxOnOff(1)
command! -buffer -nargs=* History :call w3m#history#Show()
command! -buffer -nargs=1 -complete=customlist,w3m#ListUserAgent SetUserAgent :call w3m#SetUserAgent('<args>', 1)
