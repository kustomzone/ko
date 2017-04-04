# 000   000  000   000  0000000     0000000 
# 000   000  0000  000  000   000  000   000
# 000   000  000 0 000  000   000  000   000
# 000   000  000  0000  000   000  000   000
#  0000000   000   000  0000000     0000000 
{
clamp,
first, 
last,
str,
log}  = require 'kxk'
_     = require 'lodash'

class Undo
    
    constructor: (@editor) -> @reset()

    # 00000000   00000000   0000000  00000000  000000000
    # 000   000  000       000       000          000   
    # 0000000    0000000   0000000   0000000      000   
    # 000   000  000            000  000          000   
    # 000   000  00000000  0000000   00000000     000   
        
    reset: ->
        @groupCount = 0
        @history = []
        @redos   = []
        @state   = null
                
    hasLineChanges: -> 
        return false if @history.length == 0
        return last(@history).get('lines') != @editor.state.get('lines')
                
    # 000   000  000   000  0000000     0000000 
    # 000   000  0000  000  000   000  000   000
    # 000   000  000 0 000  000   000  000   000
    # 000   000  000  0000  000   000  000   000
    #  0000000   000   000  0000000     0000000 
                    
    undo: -> 
        
        if @history.length
            
            if _.isEmpty @redos
                @redos.unshift @editor.state 
        
            @state = @history.pop()
            @redos.unshift @state
            
            changes = @calculateChanges @editor.state, @state
            @editor.setState @state
            @editor.changed? changes

    # 00000000   00000000  0000000     0000000 
    # 000   000  000       000   000  000   000
    # 0000000    0000000   000   000  000   000
    # 000   000  000       000   000  000   000
    # 000   000  00000000  0000000     0000000 

    redo: ->
        
        if @redos.length
            
            if @redos.length > 1
                @history.push @redos.shift()
                
            @state = first @redos
            if @redos.length == 1
                @redos = []
                
            changes = @calculateChanges @editor.state, @state
            @editor.setState @state
            @editor.changed? changes
                                                        
    #  0000000  000000000   0000000   00000000   000000000
    # 000          000     000   000  000   000     000   
    # 0000000      000     000000000  0000000       000   
    #      000     000     000   000  000   000     000   
    # 0000000      000     000   000  000   000     000   
        
    start: -> 
        
        @groupCount += 1
        if @groupCount == 1
            @startState = @state = @editor.state
            @history.push @state
        else
            @state = @editor.state

    # 00     00   0000000   0000000    000  00000000  000   000
    # 000   000  000   000  000   000  000  000        000 000 
    # 000000000  000   000  000   000  000  000000      00000  
    # 000 0 000  000   000  000   000  000  000          000   
    # 000   000   0000000   0000000    000  000          000   
            
    change: (index, text) ->
        return if @editor.lines[index] == text
        @state = @state.changeLine index, text 
        
    insert: (index, text) ->
        @state = @state.insertLine index, text
        
    delete: (index) ->
        if @editor.numLines() > 1
            @editor.emit 'willDeleteLine', index, @editor.lines[index]
            @state = @state.deleteLine index

    # 00000000  000   000  0000000  
    # 000       0000  000  000   000
    # 0000000   000 0 000  000   000
    # 000       000  0000  000   000
    # 00000000  000   000  0000000  

    end: (opt) -> # no log here!
        # console.log 'undo.end'
        # if opt?.foreign
        @redos = []
        @groupCount -= 1
        if @groupCount == 0
            @merge()
            changes = @calculateChanges @startState, @state
            @editor.setState @state
            @editor.changed? changes
        else
            @editor.setState @state

    #  0000000  00000000  000      00000000   0000000  000000000  000   0000000   000   000
    # 000       000       000      000       000          000     000  000   000  0000  000
    # 0000000   0000000   000      0000000   000          000     000  000   000  000 0 000
    #      000  000       000      000       000          000     000  000   000  000  0000
    # 0000000   00000000  0000000  00000000   0000000     000     000   0000000   000   000
    
    selections: (newSelections) -> 
        
        if newSelections.length
            newSelections = @editor.cleanRanges newSelections
            # log 'undo.selections', newSelections
            @state = @state.setSelections newSelections
        else
            @state = @state.setSelections []
        
    #  0000000  000   000  00000000    0000000   0000000   00000000    0000000
    # 000       000   000  000   000  000       000   000  000   000  000     
    # 000       000   000  0000000    0000000   000   000  0000000    0000000 
    # 000       000   000  000   000       000  000   000  000   000       000
    #  0000000   0000000   000   000  0000000    0000000   000   000  0000000 

    cursors: (newCursors, opt) ->

        if not newCursors? or newCursors.length < 1
            alert 'warning!! empty cursors?'
            throw new Error
        
        @cleanCursors newCursors
                
        if opt?.main 
            switch opt.main
                when 'first' then mainIndex = 0
                when 'last'  then mainIndex = newCursors.length-1
                when 'closest'
                    mainIndex = newCursors.indexOf @editor.posClosestToPosInPositions(@editor.mainCursor(), newCursors) 
                else 
                    mainIndex = newCursors.indexOf opt.main
                    mainIndex = parseInt opt.main if mainIndex < 0
        else
            mainIndex = newCursors.length-1
         
        # console.log "undo.cursors #{opt}", mainIndex, str newCursors
                    
        @state = @state.set 'main', mainIndex
        @state = @state.setCursors newCursors

    #  0000000   0000000   000       0000000  000   000  000       0000000   000000000  00000000 
    # 000       000   000  000      000       000   000  000      000   000     000     000      
    # 000       000000000  000      000       000   000  000      000000000     000     0000000  
    # 000       000   000  000      000       000   000  000      000   000     000     000      
    #  0000000  000   000  0000000   0000000   0000000   0000000  000   000     000     00000000 
    
    calculateChanges: (oldState, newState) ->
        
        oi = 0
        ni = 0
        changes = []
            
        oldLines = oldState.get 'lines'
        newLines = newState.get 'lines'

        insertions = -1
        deletions  = -1
        
        if oldLines != newLines
        
            ol = oldLines.get oi
            nl = newLines.get ni
                
            while oi < oldLines.size
                if ol == nl
                    oi += 1
                    ni += 1
                    ol = oldLines.get oi
                    nl = newLines.get ni
                else if 0 < (insertions = newLines.slice(ni).findIndex (v) -> v==ol) # insertion
                    while insertions
                        changes.push change: 'inserted', oldIndex: oi, newIndex: ni
                        ni += 1
                        insertions -= 1
                    nl = newLines.get ni
                else if 0 < (deletions = oldLines.slice(oi).findIndex (v) -> v==nl) # deletion
                    while deletions
                        changes.push change: 'deleted', oldIndex: oi, newIndex: ni
                        oi += 1
                        deletions -= 1
                    ol = oldLines.get oi
                else # change
                    changes.push change: 'changed', oldIndex: oi, newIndex: ni
                    oi += 1
                    ni += 1
                    ol = oldLines.get oi
                    nl = newLines.get ni
                
            while ni < newLines.size
                ni += 1
                changes.push change: 'inserted', oldIndex: oi, newIndex: ni
           
        changes: changes
        inserts: insertions > -1
        deletes: deletions  > -1
        cursors: oldState.get('cursors')    != newState.get('cursors')
        selects: oldState.get('selections') != newState.get('selections')
                    
    # 00     00  00000000  00000000    0000000   00000000
    # 000   000  000       000   000  000        000     
    # 000000000  0000000   0000000    000  0000  0000000 
    # 000 0 000  000       000   000  000   000  000     
    # 000   000  00000000  000   000   0000000   00000000
    
    # looks at last two actions and merges them 
    #       when they contain no line changes
    #       when they contain only changes of the same set of lines

    merge: ->
        
        while @history.length > 1
            b = @history[@history.length-2]
            a = last @history
            if a.get('lines') == b.get('lines')
                @history.splice @history.length-2, 1
            else if @history.length > 2 
                c = @history[@history.length-3]
                if a.get('lines').size == b.get('lines').size == c.get('lines').size 
                    for li in [0...a.get('lines').size]
                        la = a.getIn 'lines', li
                        lb = b.getIn 'lines', li
                        lc = c.getIn 'lines', li
                        if la == lb and lc != lb or la != lb and lc == lb
                            return
                    @history.splice @history.length-2, 2
                else return
            else return

    #  0000000  000      00000000   0000000   000   000  
    # 000       000      000       000   000  0000  000  
    # 000       000      0000000   000000000  000 0 000  
    # 000       000      000       000   000  000  0000  
    #  0000000  0000000  00000000  000   000  000   000  
    
    cleanCursors: (cs) ->

        for p in cs
            p[0] = Math.max p[0], 0
            p[1] = clamp 0, @state.numLines()-1, p[1]
            
        @editor.sortPositions cs
        
        if cs.length > 1
            for ci in [cs.length-1...0]
                c = cs[ci]
                p = cs[ci-1]
                if c[1] == p[1] and c[0] == p[0]
                    cs.splice ci, 1
        cs
        
    line: (lineIndex) -> @state.line(lineIndex)
    lines: -> @state.lines()
    numLines: -> @state.numLines()
        
module.exports = Undo
