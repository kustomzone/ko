# 000   000  000   000  0000000     0000000 
# 000   000  0000  000  000   000  000   000
# 000   000  000 0 000  000   000  000   000
# 000   000  000  0000  000   000  000   000
#  0000000   000   000  0000000     0000000 
{
first, 
last,
str,
log}  = require 'kxk'
_     = require 'lodash'
{Map} = require 'immutable'

class Undo
    
    constructor: (@editor) -> @reset()

    # 00000000   00000000   0000000  00000000  000000000
    # 000   000  000       000       000          000   
    # 0000000    0000000   0000000   0000000      000   
    # 000   000  000            000  000          000   
    # 000   000  00000000  0000000   00000000     000   
        
    reset: ->
        @history = []
        @actions = []
        @futures = []
        @redos   = []
        @groupCount = 0
        @state = null
                
    hasLineChanges: -> 
        return false if @actions.length == 0
        return last(@actions).lines.length > 0
        
    #  0000000  000   000   0000000   000   000   0000000   00000000  000  000   000  00000000   0000000 
    # 000       000   000  000   000  0000  000  000        000       000  0000  000  000       000   000
    # 000       000000000  000000000  000 0 000  000  0000  0000000   000  000 0 000  000000    000   000
    # 000       000   000  000   000  000  0000  000   000  000       000  000  0000  000       000   000
    #  0000000  000   000  000   000  000   000   0000000   00000000  000  000   000  000        0000000 

    newChangeInfo: ->
        @changeInfo = 
            lines:     false
            changed:   false
            inserted:  false
            deleted:   false
            cursors:   false
            selection: false
            
    getChangeInfo: ->
        if not @changeInfo?
            @newChangeInfo()
        @changeInfo
        
    changeInfoLineChange: () ->
        @getChangeInfo()
        @changeInfo.lines = true
        @changeInfo.changed = true

    changeInfoLineInsert: () ->
        @getChangeInfo()
        @changeInfo.lines = true
        @changeInfo.inserted = true

    changeInfoLineDelete: () ->
        @getChangeInfo()
        @changeInfo.lines = true
        @changeInfo.deleted = true
        
    changeInfoCursor: ->
        @getChangeInfo()
        @changeInfo.cursors = true

    changeInfoSelection: ->
        @getChangeInfo()
        @changeInfo.selection = true
            
    delChangeInfo: -> @changeInfo = null
        
    # 00000000   00000000  0000000     0000000 
    # 000   000  000       000   000  000   000
    # 0000000    0000000   000   000  000   000
    # 000   000  000       000   000  000   000
    # 000   000  00000000  0000000     0000000 

    redoLine: (line) ->
        switch line.change
            when 'deleted'
                @editor.lines.splice line.oldIndex, 1
                @changeInfoLineDelete()
            when 'inserted'
                @editor.lines.splice line.oldIndex, 0, line.after
                @changeInfoLineInsert()
            when 'changed'
                @editor.lines[line.oldIndex] = line.after
                @changeInfoLineChange()

    redo: ->
        # log "Undo.redo", @futures.length, @redos.length-1 if @futures.length != @redos.length-1
        if @futures.length
            
            
            @newChangeInfo()
            action = @futures.shift()
            
            for line in action.lines
                @redoLine line
            
            @redoCursor action
            @redoSelection action
            @actions.push action
            @editor.changed? @changeInfo, action
            @delChangeInfo()

        if @redos.length
            
            if @redos.length > 1
                @history.push @redos.shift()
            @editor.state = @state = first @redos
            if @redos.length == 1
                @redos = []
        
    redoSelection: (action) ->
        if action.selAfter.length
            @editor.selections = _.cloneDeep action.selAfter
            @changeInfoSelection()
        if action.selAfter.length == 0
            @changeInfoSelection()
            @editor.selections = [] 
        
    redoCursor: (action) ->
        @changeInfoCursor()
        if action.curAfter?
            @editor.cursors = action.curAfter
            @editor.mainCursor = @editor.cursors[action.mainAfter]
        @changeInfoCursor()

    # 000   000  000   000  0000000     0000000 
    # 000   000  0000  000  000   000  000   000
    # 000   000  000 0 000  000   000  000   000
    # 000   000  000  0000  000   000  000   000
    #  0000000   000   000  0000000     0000000 
    
    undoLine: (line) ->
        switch line.change
            when 'deleted'
                @editor.lines.splice line.oldIndex, 1
                @changeInfoLineDelete()
            when 'inserted'
                @editor.lines.splice line.newIndex, 0, line.after
                @changeInfoLineInsert()
            when 'changed'
                @editor.lines[line.newIndex] = line.after
                @changeInfoLineChange()
                
    undo: -> 
        
        if @history.length
            if _.isEmpty @redos
                @redos.unshift @editor.state 
        
        if @actions.length
            
            
            @newChangeInfo()
            action = @actions.pop()
            undoLines = []
            
            for line in action.lines.reversed()
                undoLines.push 
                    oldIndex:  line.newIndex
                    newIndex:  line.oldIndex
                    change:    line.change
                lastLine = last undoLines
                lastLine.before = line.after  if line.after?
                lastLine.after  = line.before if line.before?
                if line.change == 'deleted'  then lastLine.change = 'inserted'
                if line.change == 'inserted' then lastLine.change = 'deleted'
            
            sortedLines = []
            cloneLines = _.cloneDeep undoLines
            while line = cloneLines.shift()
                if line.change != 'changed'
                    for l in cloneLines
                        if l.newIndex >= line.newIndex
                            l.oldIndex += line.change == 'deleted' and -1 or 1
                sortedLines.push line
            
            changes = insertions: [], deletions: [], changes: []
            
            for line in sortedLines
                @undoLine line
                
                line.oldIndex = line.newIndex
                switch line.change
                    when 'inserted'
                        changes.insertions.push line
                            
                        for change in changes.changes
                            if change.oldIndex >= line.oldIndex
                                change.oldIndex += 1
                                change.newIndex += 1
                            
                    when 'deleted'  
                        changes.deletions.push line
                        
                    when 'changed'
                        changes.changes.push line
            
            sortedLines = changes.insertions.concat changes.deletions, changes.changes
                        
            @undoCursor action
            @undoSelection action
            @futures.unshift action
            
            @editor.changed? @changeInfo, lines: sortedLines
            @delChangeInfo()

        if @history.length
            @editor.state = @state = @history.pop()
            @redos.unshift @state
            
    undoSelection: (action) ->
        if action.selBefore.length
            @editor.selections = _.cloneDeep action.selBefore 
            @changeInfoSelection()
        if action.selBefore.length == 0
            @changeInfoSelection()
            @editor.selections = [] 
        
    undoCursor: (action) ->
        @changeInfoCursor()
        if action.curBefore?
            @editor.cursors = action.curBefore 
            @editor.mainCursor = @editor.cursors[action.mainBefore]
        @changeInfoCursor()
                        
    #  0000000  00000000  000      00000000   0000000  000000000  000   0000000   000   000
    # 000       000       000      000       000          000     000  000   000  0000  000
    # 0000000   0000000   000      0000000   000          000     000  000   000  000 0 000
    #      000  000       000      000       000          000     000  000   000  000  0000
    # 0000000   00000000  0000000  00000000   0000000     000     000   0000000   000   000
    
    selections: (newSelections) -> 
        
        if newSelections.length
            newSelections = @editor.cleanRanges newSelections
            @lastAction().selAfter = _.cloneDeep newSelections
            @editor.selections = newSelections
            @changeInfoSelection()
        else
            @changeInfoSelection()
            @editor.selections = []
            @lastAction().selAfter = []
        
    #  0000000  000   000  00000000    0000000   0000000   00000000    0000000
    # 000       000   000  000   000  000       000   000  000   000  000     
    # 000       000   000  0000000    0000000   000   000  0000000    0000000 
    # 000       000   000  000   000       000  000   000  000   000       000
    #  0000000   0000000   000   000  0000000    0000000   000   000  0000000 

    cursors: (newCursors, opt) ->
        return if not @actions.length
        if not newCursors? or newCursors.length < 1
            alert 'warning!! empty cursors?'
            throw new Error
        
        if opt?.closestMain    
            @editor.mainCursor = @editor.posClosestToPosInPositions(@editor.mainCursor, newCursors) 
        
        if newCursors.indexOf(@editor.mainCursor) < 0
            if @editor.indexOfCursor(@editor.mainCursor) >= 0
                @editor.mainCursor = newCursors[Math.min newCursors.length-1, @editor.indexOfCursor @editor.mainCursor]
            else
                @editor.mainCursor = last(newCursors)        
        
        @editor.cleanCursors newCursors
        
        if not opt?.keepInitial or newCursors.length != @editor.cursors.length
            @editor.initialCursors = _.cloneDeep newCursors
        @changeInfoCursor()
        @lastAction().curAfter  = _.cloneDeep newCursors        
        @lastAction().mainAfter = newCursors.indexOf @editor.mainCursor
        @editor.cursors = newCursors
        @changeInfoCursor()

    # 000       0000000    0000000  000000000
    # 000      000   000  000          000   
    # 000      000000000  0000000      000   
    # 000      000   000       000     000   
    # 0000000  000   000  0000000      000   
    
    lastAction: ->
        if @actions.length == 0
            @actions.push
                selBefore:  []
                selAfter:   []
                curBefore:  [[0,0]]
                curAfter:   [[0,0]]
                mainBefore: 0
                mainAfter:  0
                lines:      []
        return @actions[@actions.length-1]
            
    #  0000000  000000000   0000000   00000000   000000000
    # 000          000     000   000  000   000     000   
    # 0000000      000     000000000  0000000       000   
    #      000     000     000   000  000   000     000   
    # 0000000      000     000   000  000   000     000   
        
    start: -> 
        @groupCount += 1
        if @groupCount == 1
            @state = @editor.state
            @history.push @state
            
            a = @lastAction()
            @actions.push 
                selBefore:  _.clone a.selAfter
                curBefore:  _.clone a.curAfter
                selAfter:   _.clone a.selAfter
                curAfter:   _.clone a.curAfter
                mainBefore: a.mainBefore
                mainAfter:  a.mainAfter
                lines:      []

    # 00     00   0000000   0000000    000  00000000  000   000
    # 000   000  000   000  000   000  000  000        000 000 
    # 000000000  000   000  000   000  000  000000      00000  
    # 000 0 000  000   000  000   000  000  000          000   
    # 000   000   0000000   0000000    000  000          000   
    
    moveLinesAfter: (index, dy) ->
        for change in @lastAction().lines
            if change.oldIndex > index
                change.newIndex += dy
    
    modify: (change) ->
        
        lines = @lastAction().lines
                        
        change.newIndex = change.oldIndex
        if change.change == 'deleted'
            @moveLinesAfter change.oldIndex, -1
        else if change.change == 'inserted'
            @moveLinesAfter change.oldIndex-1,  1
        lines.push change
        
    change: (index, text) ->
        return if @editor.lines[index] == text
        @modify
            change:   'changed'
            before:   @editor.lines[index]
            after:    text
            oldIndex: index
        @editor.lines[index] = text
        @state = @state.update 'lines', (l) -> l.set index, new Map text:text
        @changeInfoLineChange()
        
    insert: (index, text) ->
        @modify
            change:   'inserted'
            after:    text 
            oldIndex: index
        @editor.lines.splice index, 0, text
        @state = @state.update 'lines', (l) -> l.splice index, 0, new Map text:text
        @changeInfoLineInsert()
        
    delete: (index) ->
        if @editor.lines.length > 1
            @modify
                change:   'deleted'
                before:   @editor.lines[index] 
                oldIndex: index
            @editor.emit 'willDeleteLine', index, @editor.lines[index]
            @editor.lines.splice index, 1
            @state = @state.update 'lines', (l) -> l.splice index, 1
            @changeInfoLineDelete()
        else
            alert 'warning! last line deleted?'
            throw new Error

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
        
        if oldLines == newLines then return changes
        
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
           
        # console.log 'calculateChanges', str changes if changes.length
        changes
        
    # 00000000  000   000  0000000  
    # 000       0000  000  000   000
    # 0000000   000 0 000  000   000
    # 000       000  0000  000   000
    # 00000000  000   000  0000000  

    end: (opt) -> # no log here!
        
        if opt?.foreign
            @changeInfo?.foreign = opt.foreign
            
        @groupCount -= 1
        @futures = []
        
        if @groupCount == 0

            @merge()
            @mergeHistory()
            
            if @changeInfo?
                @changeInfo.changes = @calculateChanges @editor.state, @state
                @editor.changedNew? @changeInfo
                @delChangeInfo()
  
            @editor.state = @state
            
    # 00     00  00000000  00000000    0000000   00000000
    # 000   000  000       000   000  000        000     
    # 000000000  0000000   0000000    000  0000  0000000 
    # 000 0 000  000       000   000  000   000  000     
    # 000   000  00000000  000   000   0000000   00000000
    
    # looks at last two actions and merges them 
    #       when they contain no line changes
    #       when they contain only changes of the same set of lines

    mergeHistory: ->
        
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
    
    merge: ->
                
        while @actions.length >= 2
            b = @actions[@actions.length-2]
            a = last @actions
            if a.lines.length == 0 and b.lines.length == 0
                @actions.pop()
                b.selAfter  = a.selAfter
                b.curAfter  = a.curAfter
                b.mainAfter = a.mainAfter
            else if a.lines.length == b.lines.length
                sameLines = true
                for i in [0...a.lines.length]
                    if a.lines[i].oldIndex != b.lines[i].oldIndex or 
                        a.lines[i].change != b.lines[i].change or a.lines[i].change != 'changed' or
                            not a.lines[i].after or not b.lines[i].after or
                                Math.abs(a.lines[i].after.length - b.lines[i].after.length) > 1
                                    return
                if sameLines
                    @actions.pop()
                    b.selAfter  = a.selAfter
                    b.curAfter  = a.curAfter
                    b.mainAfter = a.mainAfter
                    for i in [0...a.lines.length]
                        b.lines[i].after = a.lines[i].after
                else return
            else return                    
        
module.exports = Undo
