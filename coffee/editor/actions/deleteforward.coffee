# 00000000   0000000   00000000   000   000   0000000   00000000   0000000  
# 000       000   000  000   000  000 0 000  000   000  000   000  000   000
# 000000    000   000  0000000    000000000  000000000  0000000    000   000
# 000       000   000  000   000  000   000  000   000  000   000  000   000
# 000        0000000   000   000  00     00  000   000  000   000  0000000  
    
module.exports = 
    
    info:
        name:   'delte forward'
        combos: ['delete', 'ctrl+backspace']
        text:   'delete character to the right of cursors'

    deleteForward: ->
        if @numSelections()
            @deleteSelection()
        else
            @do.start()
            newCursors = @do.cursors()
            for c in newCursors.reversed()
            
                if @isCursorAtEndOfLine c # cursor at end of line
                    if not @isCursorInLastLine c # cursor not in first line
                    
                        ll = @lines[c[1]].length
                    
                        @do.change c[1], @lines[c[1]] + @lines[c[1]+1]
                        @do.delete c[1]+1
                                    
                        # move cursors in joined line
                        for nc in @positionsForLineIndexInPositions c[1]+1, newCursors
                            @cursorDelta nc, ll, -1
                        # move cursors below deleted line up
                        for nc in @positionsBelowLineIndexInPositions c[1]+1, newCursors
                            @cursorDelta nc, 0, -1
                else
                    @do.change c[1], @lines[c[1]].splice c[0], 1
                    for nc in @positionsForLineIndexInPositions c[1], newCursors
                        if nc[0] > c[0]
                            @cursorDelta nc, -1

            @do.cursor newCursors
            @do.end()