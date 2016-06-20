#  0000000   00000000   00000000  000   000
# 000   000  000   000  000       0000  000
# 000   000  00000000   0000000   000 0 000
# 000   000  000        000       000  0000
#  0000000   000        00000000  000   000
{
fileExists,
dirExists,
relative,
resolve,
clamp,
last,
$}      = require '../tools/tools'
log     = require '../tools/log'
profile = require '../tools/profile'
Command = require '../commandline/command'
render  = require '../editor/render'
syntax  = require '../editor/syntax'
path    = require 'path'
walkdir = require 'walkdir'
fuzzy   = require 'fuzzy'
fs      = require 'fs'
_       = require 'lodash'

fileTypes = [
    'coffee', 'js', 
    'styl', 'css'
    'pug', 'jade', 'html', 
    'md', 'txt',
    'noon', 'json', 
    'cpp', 'h',
    'sh', 'py'
    ]
fileExtensions = (".#{e}" for e in fileTypes)    
    
class Open extends Command

    constructor: (@commandline) ->
        
        @shortcuts = ['command+p', 'command+shift+p']
        @files     = null
        @file      = null
        @dir       = null
        @pkg       = null
        @combo     = null
        @selected  = 0
        
        super
                    
    #  0000000  000   000   0000000   000   000   0000000   00000000  0000000  
    # 000       000   000  000   000  0000  000  000        000       000   000
    # 000       000000000  000000000  000 0 000  000  0000  0000000   000   000
    # 000       000   000  000   000  000  0000  000   000  000       000   000
    #  0000000  000   000  000   000  000   000   0000000   00000000  0000000  

    changed: (command) ->
        return if not @list? 
        command  = command.trim()
        if command.length
            fuzzied  = fuzzy.filter command, @files       
            filtered = (f.string for f in fuzzied)
            
            matchWeight = (f) ->
                bonus = switch path.extname(f)         
                    when '.coffee' then 100
                    when '.md', '.styl', '.pug' then 50
                    when '.noon' then 25
                    when '.js', '.json', '.html' then -100
                    else 
                        0 
                        
                if f == command 
                    bonus += 99999999
                if f.startsWith command
                    bonus += 100000 - f.length                        
                if path.basename(f).startsWith command
                    bonus += 10000 - path.basename(f).length
                bonus
                
            filtered.sort (a,b) -> matchWeight(b) - matchWeight(a)
            @listFiles filtered
        else
            @listFiles @files
        
        @select 0

    # 000      000   0000000  000000000
    # 000      000  000          000   
    # 000      000  0000000      000   
    # 000      000       000     000   
    # 0000000  000  0000000      000   

    showList: ->
        @list?.remove()
        @list = document.createElement 'div'
        @list.className = 'list'
        @list.style.top = window.split.editHandle.style.top
        window.split.elem.appendChild @list 
        @listFiles @files
            
    listFiles: (files) ->
        @list.innerHTML = ""        
        if files.length == 0
            @list.style.display = 'none'
        else
            @list.style.display = 'unset'
            index = 0
            for file in files
                div = document.createElement 'div'
                div.className = 'list-file'
                div.innerHTML = render.line file, syntax.dissForTextAndSyntax file, 'ko'
                div.setAttribute "onclick", "window.openFileAtIndex(#{index});"
                div.value = file
                @list.appendChild div
                index += 1
                
    # 00000000   00000000   00000000  000   000
    # 000   000  000   000  000       000   000
    # 00000000   0000000    0000000    000 000 
    # 000        000   000  000          000   
    # 000        000   000  00000000      0    
            
    prev: -> 
        if @index == @history.length-1 and @selected > 0
            @select clamp 0, @list.children.length, @selected-1
            @list.children[@selected]?.value ? @history[@index]
        else
            super
        
    # 000   000  00000000  000   000  000000000
    # 0000  000  000        000 000      000   
    # 000 0 000  0000000     00000       000   
    # 000  0000  000        000 000      000   
    # 000   000  00000000  000   000     000   
    
    next: -> 
        if @index == @history.length-1
            @select clamp 0, @list.children.length, @selected+1
            @list.children[@selected]?.value ? @history[@index]
        else
            super
        
    #  0000000  00000000  000      00000000   0000000  000000000
    # 000       000       000      000       000          000   
    # 0000000   0000000   000      0000000   000          000   
    #      000  000       000      000       000          000   
    # 0000000   00000000  0000000  00000000   0000000     000   
        
    select: (i) ->
        @list?.children[@selected]?.className = 'list-file'
        @selected = clamp 0, @list?.children.length-1, i
        @list?.children[@selected]?.className = 'list-file selected'
        @list?.children[@selected]?.scrollIntoViewIfNeeded()
        
    #  0000000   00000000   00000000  000   000  00000000  000  000      00000000
    # 000   000  000   000  000       0000  000  000       000  000      000     
    # 000   000  00000000   0000000   000 0 000  000000    000  000      0000000 
    # 000   000  000        000       000  0000  000       000  000      000     
    #  0000000   000        00000000  000   000  000       000  0000000  00000000
        
    openFileAtIndex: (i) =>
        @select i
        e = @execute @list.children[i].value
        if e.focus == 'editor'
            @setText e.text
            @commandline.selectNone()
            window.split.focusEditor()
    
    #  0000000  000000000   0000000   00000000   000000000
    # 000          000     000   000  000   000     000   
    # 0000000      000     000000000  0000000       000   
    #      000     000     000   000  000   000     000   
    # 0000000      000     000   000  000   000     000   
        
    start: (@combo) -> 
        window.openFileAtIndex = @openFileAtIndex
        @files = []
        @selected = 0
        if window.editor.currentFile?
            @file  = window.editor.currentFile 
            @dir   = path.dirname @file
            @pkg   = @packagePath @dir
        else 
            @file = null
            if not @dir?
                @dir = @pkg = resolve '~'
            
        @startWalker()
        
        if @combo == @shortcuts[1]
            @setName "new window"
            
        return ""
        
    # 000   000   0000000   000      000   000  00000000  00000000 
    # 000 0 000  000   000  000      000  000   000       000   000
    # 000000000  000000000  000      0000000    0000000   0000000  
    # 000   000  000   000  000      000  000   000       000   000
    # 00     00  000   000  0000000  000   000  00000000  000   000
            
    startWalker: ->           
        # profile 'walker start'
        that = @
        try
            dir = @pkg ? @dir
            @walker = walkdir.walk dir, max_depth: 3
            
            onWalkerPath = (dir) -> (p,stat) ->
                name = path.basename p
                extn = path.extname p
                if name in ['node_modules', 'app', 'img', 'dist', 'build', 'Library', 'Applications']
                    @ignore p 
                else if name in ['.konrad.noon', '.gitignore', '.npmignore']
                    that.files.push p
                else if (name.startsWith '.') or extn in ['.app']
                    @ignore p 
                else if extn in fileExtensions
                    that.files.push p
                else if stat.isDirectory()
                    if p != dir
                        that.files.push p 
                        
                if that.files.length > 500
                    # log 'max files reached', @end?
                    @end()
            
            @walker.on 'path', onWalkerPath dir
            @walker.on 'end', @walkerDone
                
        catch err
            log "open.startWalker.error: #{err} dir: #{dir}"
            log "#{err.stack}"
            
    walkerDone: =>
        # profile 'walker done'
        # log "walkerDone @dir #{@dir}"
        
        # 000   000  00000000  000   0000000   000   000  000000000
        # 000 0 000  000       000  000        000   000     000   
        # 000000000  0000000   000  000  0000  000000000     000   
        # 000   000  000       000  000   000  000   000     000   
        # 00     00  00000000  000   0000000   000   000     000   
        
        absWeight = (f) =>
            
            penalty = path.dirname(f).length            
                            
            if f.startsWith @dir
                return 10000-penalty
            if f.startsWith path.dirname @dir
                return 5000-penalty
            else
                return 1000-penalty
        
        relWeight = (f) =>
            
            bonus = switch path.extname(f)         
                when '.coffee' then 100
                when '.md', '.styl', '.pug' then 50
                when '.noon' then 25
                when '.js', '.json', '.html' then -1000000
                else 
                    0 
                                
            return bonus + 100*(100-f.split(/[\/\.]/).length) #- f.length
                            
        @files.sort (a,b) -> absWeight(b) - absWeight(a)
                
        @files = (relative(f, @dir) for f in @files)
        
        @files = @files.filter (f) -> f.length 
        @files.sort (a,b) -> relWeight(b) - relWeight(a)

        if @history.length
            h = (relative(f, @dir) for f in @history when f.length and (f != @file))
            @lastFileIndex = h.length - 1
            @files = _.concat h, @files

        @files = _.uniq @files

        @showList()
        @select @lastFileIndex
        if @lastFileIndex >= 0   
            @commandline.setAndSelectText @list?.children[@selected]?.value 
                    
    # 00000000  000   000  00000000   0000000  000   000  000000000  00000000
    # 000        000 000   000       000       000   000     000     000     
    # 0000000     00000    0000000   000       000   000     000     0000000 
    # 000        000 000   000       000       000   000     000     000     
    # 00000000  000   000  00000000   0000000   0000000      000     00000000
        
    execute: (command) ->
        
        listValue = @list?.children[@selected]?.value

        if command in ['pwd', '.']
            return text: @dir, select: true
        else
            if dirExists @resolvedPath command
                resolved = @resolvedPath command
            else if listValue? 
                if dirExists @resolvedPath listValue
                    resolved = listValue
            if resolved?
                @dir = resolved
                @pkg = @packagePath @dir
                @lastFileIndex = -1
                @files = []
                @selected = 0
                @startWalker()
                return text: @dir, select: true

        @hideList()

        if listValue
            files = [@resolvedPath listValue]
        else
            files = _.words command, new RegExp "[^, ]+", 'g'
                    
            for i in [0...files.length]
                file = files[i]
                file = @resolvedPath file
                if not fileExists file
                    if '' == path.extname file
                        if fileExists file + '.coffee'
                            file += '.coffee'
                files.splice i, 1, file
            
        options = 
            newWindow: @combo == @shortcuts[1] # lazy bastard :)
        
        opened = window.openFiles files, options
        if opened?.length
            if opened.length == 1
                super opened[0]
            else
                super selected
                
            text:  (path.basename(f) for f in opened).join ' '
            focus: 'editor'
            status: 'ok'
        else
            status: 'failed'

    # 00000000    0000000    0000000  000   000   0000000    0000000   00000000
    # 000   000  000   000  000       000  000   000   000  000        000     
    # 00000000   000000000  000       0000000    000000000  000  0000  0000000 
    # 000        000   000  000       000  000   000   000  000   000  000     
    # 000        000   000   0000000  000   000  000   000   0000000   00000000
    
    packagePath: (p) ->
        while p.length and p not in ['.', '/']            
            if fs.existsSync path.join p, 'package.noon'
                return resolve p
            if fs.existsSync path.join p, 'package.json'
                return resolve p
            p = path.dirname p
        null
    
    # 00000000   00000000   0000000   0000000   000      000   000  00000000  0000000  
    # 000   000  000       000       000   000  000      000   000  000       000   000
    # 0000000    0000000   0000000   000   000  000       000 000   0000000   000   000
    # 000   000  000            000  000   000  000         000     000       000   000
    # 000   000  00000000  0000000    0000000   0000000      0      00000000  0000000  
    
    resolvedPath: (p, parent=@dir) ->
        return parent if not p?
        if p[0] in ['~', '/']
            resolve p
        else
            resolve path.join parent, p
        
    # 000   000  000  0000000    00000000
    # 000   000  000  000   000  000     
    # 000000000  000  000   000  0000000 
    # 000   000  000  000   000  000     
    # 000   000  000  0000000    00000000
            
    hideList: ->
        @list?.remove()
        @list = null
                
    cancel: ->
        @hideList()
        super
        
module.exports = Open