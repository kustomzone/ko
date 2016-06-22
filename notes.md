# todo/ideas

#### find
- *search in multiple files*
- *scroll find result to top of view*
- *escape dots in search string*
- highlight while entering

#### search
- *output start and end*
- use syntax of file for search result display
- make search results clickable
- make search results editable
- make search results keyboard navigatable

#### editor
- fix esc
- check undo (merges too much?)
- *autocomple*
    - from buffer
    - from similar files

#### open
- don't select recent when pwd was changed

#### terminal
- *output command*
- *alias*
- *ansihtml*
- add special column (on top of numbers) for input marker and search result lines
- shortcuts to hide editor / center input
- autocomplete
    - dirs and files
    - /usr/local/bin, /usr/bin and /bin
- font zoom shortcut
- number history output and add !# command
      
#### logview
- font zoom shortcut
      
#### misc    
- command-enter: deselect, insert newline, indent, and single cursor
- comment line characters per filetype    
- remember scroll positions per file
    
#### minimap
- show selections, highlights and cursors
- *don't render beyond minimap width*
    
#### cursors
- *fix initialCursors mess*
- remember last cursor
- highlight last cursor
- highlight cursor line(s?)
- insert spaces when inserting at virtual cursors
- paste multiple lines into multiple selections/cursors

#### selection
- two selection modes
- active (cursor inside)
- passive (cursor movement won't destroy, but next selection will)
- restore cursor and scroll
- on watcher reload
- on save/saveAs reload
- shift move cursor down
- extend selection to end of line if previous line is fully selected
    
#### editing
- make special stuff file type dependent, eg. add * to surround characters for md
- when pasting text at indent level, remove leading space columns
- ctrl+command+/  align cursor block
- dont switch to multicursors on shift-right/left
- insert newline if pasting fully selected lines
- indent one level more when inserting newline ...
    - after =>, -> 
    - when next line is indented one level more
- surround selection with #{} if inside string
    - autoconvert '' to "" when #{} entered
- dbg "class.method arg: #{arg}, ..."
- history of file locations

#### minimap 
- shift drag: extend selection
- command drag: don't clear selection and don't single select
- more linear scrolling when dragging

#### syntax
- fix md
- pug, html, js

#### commands
- tree
- tabs?
- ls
- shell
- execute
- cat
    - images

#### nice to have
- bracket matching
- git status in gutter?
- show invisbles (spaces,tabs,etc)
- history,console,terminal
- shortcut for renaming file
- pin
    - command
    - shortcut
- tail -f mode
- markdown mode (replace - with ●)
- cosmetic
    - fix highlight rounded borders     