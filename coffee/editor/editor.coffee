# 00000000  0000000    000  000000000   0000000   00000000 
# 000       000   000  000     000     000   000  000   000
# 0000000   000   000  000     000     000   000  0000000  
# 000       000   000  000     000     000   000  000   000
# 00000000  0000000    000     000      0000000   000   000
{
fileList,
extName,
clamp,
str,
log,
$}      = require 'kxk'
Buffer  = require './buffer'
Syntax  = require './syntax'
Do      = require './do'
path    = require 'path'
_       = require 'lodash'

class Editor extends Buffer

    @actions = null

    constructor: () ->

        Editor.initActions() if not Editor.actions?
            
        @surroundStack      = []
        @surroundCharacters = []
        @surroundPairs      = Object.create null
        @indentString       = _.padStart "", 4
        @stickySelection    = false
        @dbg                = false
        super
        @do                 = new Do @
        @setupFileType()

    # 000  000   000  000  000000000       0000000    0000000  000000000  000   0000000   000   000   0000000  
    # 000  0000  000  000     000         000   000  000          000     000  000   000  0000  000  000       
    # 000  000 0 000  000     000         000000000  000          000     000  000   000  000 0 000  0000000   
    # 000  000  0000  000     000         000   000  000          000     000  000   000  000  0000       000  
    # 000  000   000  000     000         000   000   0000000     000     000   0000000   000   000  0000000   
    
    @initActions: -> 
        @actions = []
        for actionFile in fileList path.join __dirname, 'actions'
            actions = require actionFile
            for key,value of actions
                if _.isFunction value
                    @prototype[key] = value
                else if key == 'actions'
                    for k,v of value
                        v.key = k if not v.key?
                        @actions.push v
                        
        # too early for log here!            
        # console.log str @actions

    # 000000000  000   000  00000000   00000000
    #    000      000 000   000   000  000     
    #    000       00000    00000000   0000000 
    #    000        000     000        000     
    #    000        000     000        00000000
    
    setupFileType: ->
        oldType   = @fileType
        @fileType = 'txt'
        @fileType = Syntax.shebang @line(0) if @numLines()
        if @fileType == 'txt' and @currentFile?
            ext = extName @currentFile
            if ext in Syntax.syntaxNames
                @fileType = ext
                
        # _______________________________________________________________ strings
        
        @stringCharacters =
            "'":  'single'
            '"':  'double'
        switch @fileType
            when 'md' then @stringCharacters['*'] = 'bold'
            when 'noon' then @stringCharacters['|'] = 'pipe'

        # _______________________________________________________________ brackets
        
        @bracketCharacters = 
            open:
                '[': ']'
                '{': '}'
                '(': ')'
            close: {} # reverse map, not needed?
            regexps: []
                
        switch @fileType
            when 'html' then @bracketCharacters.open['<'] = '>'

        for k,v of @bracketCharacters.open
            @bracketCharacters.close[v] = k
        
        @bracketCharacters.regexp = []
        for key in ['open', 'close']
            cstr = _.keys(@bracketCharacters[key]).join ''
            reg = new RegExp "[#{_.escapeRegExp cstr}]"
            @bracketCharacters.regexps.push [reg, key]
        
        # _______________________________________________________________ surround
        
        @surroundPairs = 
            '[': ['[', ']']
            ']': ['[', ']']
            '{': ['{', '}']
            '}': ['{', '}']
            '(': ['(', ')']
            ')': ['(', ')']
            '<': ['<', '>']
            '>': ['<', '>']
            '#': ['#{', '}']
            "'": ["'", "'"]
            '"': ['"', '"']
            '*': ['*', '*']                    
        
        @surroundCharacters = "{}[]()\"'".split ''
        switch @fileType
            when 'html'   then @surroundCharacters = @surroundCharacters.concat ['<','>']
            when 'coffee' then @surroundCharacters.push '#'
            when 'md'     
                @surroundCharacters = @surroundCharacters.concat ['*','<']
                @surroundPairs['<'] = ['<!---', '--->']
            
        # _______________________________________________________________ indent
        
        @indentNewLineMore = null
        @indentNewLineLess = null
        @insertIndentedEmptyLineBetween = '{}'
        
        switch @fileType
            when 'coffee' 
                @indentNewLineMore = 
                    lineEndsWith: ['->', '=>', ':', '=']
                    beforeRegExp: /(^|\s)(else\s*$|switch\s|for\s|while\s|class\s)/
                    lineRegExp:   /^(\s+when|\s*if|\s*else\s+if\s+)(?!.*\sthen\s)/
                @indentNewLineLess = 
                    beforeRegExp: /^s+return/
                
        # _______________________________________________________________ comment
        
        @lineComment = switch @fileType
            when 'cpp', 'cc', 'hpp', 'h', 'styl', 'pug' then '//'
            else '#'  
            
        if oldType != @fileType
            @emit 'fileTypeChanged', @fileType
                
    #  0000000  00000000  000000000         000      000  000   000  00000000   0000000  
    # 000       000          000            000      000  0000  000  000       000       
    # 0000000   0000000      000            000      000  000 0 000  0000000   0000000   
    #      000  000          000            000      000  000  0000  000            000  
    # 0000000   00000000     000            0000000  000  000   000  00000000  0000000   

    setText: (text="") -> 
        rgx = new RegExp '\t', 'g'
        indent = @indentString
        @setLines text.split(/\n/).map (l) -> l.replace rgx, indent

    setLines: (lines) ->
        super lines
        @emit 'linesSet', lines
        
    textOfSelectionForClipboard: -> 
        if @numSelections()
            @textOfSelection()
        else
            @textInRanges @rangesForCursorLines()
                
    # 00000000  00     00  000  000000000       00000000  0000000    000  000000000
    # 000       000   000  000     000          000       000   000  000     000   
    # 0000000   000000000  000     000          0000000   000   000  000     000   
    # 000       000 0 000  000     000          000       000   000  000     000   
    # 00000000  000   000  000     000          00000000  0000000    000     000   

    emitEdit: (action) ->
        mc = @mainCursor()
        line = @line mc[1] 
        @emit 'edit',
            action: action
            line:   line
            before: line.slice 0, mc[0]
            after:  line.slice mc[0]
            cursor: mc
    
    # 000  000   000  0000000    00000000  000   000  000000000   0000000  000000000  00000000   
    # 000  0000  000  000   000  000       0000  000     000     000          000     000   000  
    # 000  000 0 000  000   000  0000000   000 0 000     000     0000000      000     0000000    
    # 000  000  0000  000   000  000       000  0000     000          000     000     000   000  
    # 000  000   000  0000000    00000000  000   000     000     0000000      000     000   000  
    
    indentStringForLineAtIndex: (li) -> 
        if li < @numLines()
            il = 0
            thisIndent = @indentationAtLineIndex li
            indentLength = @indentString.length
            
            if @indentNewLineMore?
                if @indentNewLineMore.lineEndsWith?.length
                    for e in @indentNewLineMore.lineEndsWith
                        if @line(li).endsWith e
                            il = thisIndent + indentLength
                            break
                if il == 0
                    if @indentNewLineMore.lineRegExp? and @indentNewLineMore.lineRegExp.test @line(li)
                        il = thisIndent + indentLength
                        
            il = thisIndent if il == 0
            il = Math.max il, @indentationAtLineIndex li+1
            
            _.padStart "", il
        else
            ''

module.exports = Editor