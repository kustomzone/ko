#  0000000  00000000  000      00000000   0000000  000000000  000   0000000   000   000
# 000       000       000      000       000          000     000  000   000  0000  000
# 0000000   0000000   000      0000000   000          000     000  000   000  000 0 000
#      000  000       000      000       000          000     000  000   000  000  0000
# 0000000   00000000  0000000  00000000   0000000     000     000   0000000   000   000
{
error,
log
} = require 'kxk'
_ = require 'lodash'

module.exports =
    
    actions:
        startStickySelection:
            name:  'sticky selection mode'
            text:  'current selection is not removed when adding new selections'
            combo: 'command+esc'
        selectAll:
            name:  'select all lines'
            combo: 'command+a'
        selectNone:
            name:  'deselect'
            combo: 'command+shift+a'
        selectInverted:
            name:  'invert selection'
            text:  'selects all lines that have no cursors and no selections'
            combo: 'command+i'
        selectNextHighlight:
            name:  'select next highlight'
            combo: 'command+g'
        selectPrevHighlight:
            name:  'select previous highlight'
            combo: 'command+shift+g'
        selectAllHighlights:
            name:  'select all highlights'
            combo: 'command+alt+d'
        selectTextBetweenCursorsOrSurround:
            name: 'select between cursors|brackets|quotes'
            text: """
                select text between even cursors, if at least two cursors exist. 
                select text between highlighted brackets or quotes otherwise.
                """
            combo: 'command+alt+ctrl+b'

    selectSingleRange: (r, opt = extend:false) ->
        @startSelectionCursors = null if not opt.extend
        if not r?
            return error "Editor.#{name}.selectSingleRange -- undefined range!"
        @do.start()
        @do.setCursors [[opt?.before and r[1][0] or r[1][1], r[0]]]
        @do.select [r]
        @do.end()

    #  0000000  000000000  000   0000000  000   000  000   000  
    # 000          000     000  000       000  000    000 000   
    # 0000000      000     000  000       0000000      00000    
    #      000     000     000  000       000  000      000     
    # 0000000      000     000   0000000  000   000     000     
    
    startStickySelection: () -> 
        @stickySelection = true
        @updateTitlebar?()
        @emit 'selection'

    endStickySelection: () ->
        @stickySelection = false
        @updateTitlebar?()
        @emit 'selection'

    #  0000000  000000000   0000000   00000000   000000000          00000000  000   000  0000000    
    # 000          000     000   000  000   000     000             000       0000  000  000   000  
    # 0000000      000     000000000  0000000       000     000000  0000000   000 0 000  000   000  
    #      000     000     000   000  000   000     000             000       000  0000  000   000  
    # 0000000      000     000   000  000   000     000             00000000  000   000  0000000    
    
    startSelection: (opt = extend:false) ->
        if opt?.extend
            if not @startSelectionCursors
                @startSelectionCursors = @do.cursors()
                if not @stickySelection
                    @do.select rangesFromPositions @startSelectionCursors
        else
            @startSelectionCursors = null
            if not @stickySelection
                @do.select []
                    
    endSelection: (opt = extend:false) ->
        if not opt?.extend
            if @do.numSelections() and not @stickySelection
                @selectNone()
            @startSelectionCursors = null
        else
            oldCursors   = @startSelectionCursors ? @do.cursors()
            newSelection = @stickySelection and @do.selections() or []            
            newCursors   = @do.cursors()
            
            if oldCursors.length != newCursors.length
                log 'startSelectionCursors', @startSelectionCursors?.length
                return error "Editor.#{@name}.endSelection -- oldCursors.size != newCursors.size", oldCursors.length, newCursors.length
            
            for ci in [0...@do.numCursors()]
                oc = oldCursors[ci]
                nc = newCursors[ci]
                if not oc? or not nc?
                    return error "Editor.#{@name}.endSelection -- invalid cursors", oc, nc
                else
                    ranges = @rangesBetweenPositions oc, nc, true #< extend to full lines if cursor at start of line                
                    newSelection = newSelection.concat ranges

            @do.select newSelection
        @checkSalterMode()      

    #  0000000   0000000    0000000    
    # 000   000  000   000  000   000  
    # 000000000  000   000  000   000  
    # 000   000  000   000  000   000  
    # 000   000  0000000    0000000    
    
    addRangeToSelection: (range) ->
        @do.start()
        newSelections = @do.selections()
        newSelections.push range
        newCursors = (rangeEndPos(r) for r in newSelections)
        @do.setCursors newCursors, main:'last'
        @do.select newSelections
        @do.end()

    removeSelectionAtIndex: (si) ->
        @do.start()
        newSelections = @do.selections()
        newSelections.splice si, 1
        if newSelections.length
            newCursors = (rangeEndPos(r) for r in newSelections)
            @do.setCursors newCursors, main:(newCursors.length+si-1) % newCursors.length
        @do.select newSelections
        @do.end()        

    selectNone: -> 
        @do.start()
        @do.select []
        @do.end()
        
    selectAll: -> 
        @do.start()
        @do.select @rangesForAllLines()
        @do.end()
        
    # 000  000   000  000   000  00000000  00000000   000000000  
    # 000  0000  000  000   000  000       000   000     000     
    # 000  000 0 000   000 000   0000000   0000000       000     
    # 000  000  0000     000     000       000   000     000     
    # 000  000   000      0      00000000  000   000     000     
    
    selectInverted: -> 
        invertedRanges = []        
        sc = @selectedAndCursorLineIndices()
        for li in [0...@numLines()]
            if li not in sc
                invertedRanges.push @rangeForLineAtIndex li
        if invertedRanges.length
            @do.start()
            @do.setCursors [rangeStartPos _.first invertedRanges]
            @do.select invertedRanges
            @do.end()     

    # 0000000    00000000  000000000  000   000  00000000  00000000  000   000  
    # 000   000  000          000     000 0 000  000       000       0000  000  
    # 0000000    0000000      000     000000000  0000000   0000000   000 0 000  
    # 000   000  000          000     000   000  000       000       000  0000  
    # 0000000    00000000     000     00     00  00000000  00000000  000   000  
    
    selectTextBetweenCursorsOrSurround: ->
        #  [(test)]
        if @numCursors() and @numCursors() % 2 == 0  
            @do.start()
            newSelections = []
            newCursors = []
            oldCursors = @do.cursors()
            for i in [0...oldCursors.length] by 2
                c0 = oldCursors[i]
                c1 = oldCursors[i+1]
                newSelections = newSelections.concat @rangesBetweenPositions c0, c1
                newCursors.push c1
            @do.setCursors newCursors
            @do.select newSelections
            @do.end()
        else @selectBetweenSurround()

    selectBetweenSurround: ->
        if surr = @highlightsSurroundingCursor()
            @do.start()
            start = rangeEndPos surr[0]
            end = rangeStartPos surr[1]
            s = @rangesBetweenPositions start, end
            s = @cleanRanges s
            if s.length
                @do.select s
                if @do.numSelections()
                    @do.setCursors [rangeEndPos(_.last s)], Main: 'closest'
            @do.end()
            
    selectSurround: ->
        if surr = @highlightsSurroundingCursor()
            @do.start()
            @do.select surr
            if @do.numSelections()
                @do.setCursors (rangeEndPos(r) for r in @do.selections()), main: 'closest'
            @do.end()

    # 000   000  000   0000000   000   000  000      000   0000000   000   000  000000000   0000000  
    # 000   000  000  000        000   000  000      000  000        000   000     000     000       
    # 000000000  000  000  0000  000000000  000      000  000  0000  000000000     000     0000000   
    # 000   000  000  000   000  000   000  000      000  000   000  000   000     000          000  
    # 000   000  000   0000000   000   000  0000000  000   0000000   000   000     000     0000000   
        
    selectNextHighlight: -> # command+g
        if not @numHighlights() and window? # < this sucks
            searchText = window.commandline.commands.find?.currentText
            @highlightText searchText if searchText?.length
        return if not @numHighlights()
        r = rangeAfterPosInRanges @cursorPos(), @highlights()
        r ?= @highlight 0
        if r?
            @selectSingleRange r, before: r[2]?.value == 'close'
            @scrollCursorIntoView?() # < this also sucks

    selectPrevHighlight: -> # command+shift+g
        if not @numHighlights() and window? # < this sucks
            searchText = window.commandline.commands.find?.currentText
            @highlightText searchText if searchText?.length
        return if not @numHighlights()
        hs = @highlights()
        r = rangeBeforePosInRanges @cursorPos(), hs
        r ?= _.last hs
        @selectSingleRange r if r?

