#  0000000   0000000   000      000000000  00000000  00000000   
# 000       000   000  000         000     000       000   000  
# 0000000   000000000  000         000     0000000   0000000    
#      000  000   000  000         000     000       000   000  
# 0000000   000   000  0000000     000     00000000  000   000  

{log} = require 'kxk'  
{Set} = require 'immutable'
salt  = require '../../tools/salt'  
_     = require 'lodash'

module.exports =
    
    actions:
        startSalter:
            name: 'ascii-header mode'
            text: """if cursor is not in ascii-header: 
                insert ascii-header of text in selection or word at cursor.
                switch to ascii-header mode in any case.
                """
            combo: 'command+3'

    startSalter: (opt) ->
        cp = @cursorPos()
        if not opt?.word and rgs = @salterRangesAtPos cp # edit existing header
            cols = @columnsInSalt (@textInRange r for r in rgs)
            ci = 0
            while ci < cols.length and cp[0] > cols[ci]
                ci += 1
            col = cols[ci]
            @do.start()
            newCursors = ([col, r[0]] for r in rgs)
            @do.setCursors newCursors, main: 'last'
            @do.end()
        else # create new header
            word = opt?.word ? @selectionTextOrWordAtCursor().trim()
            if @textInRange(@rangeForLineAtIndex cp[1]).trim().length
                indt = _.padStart '', @indentationAtLineIndex cp[1]
            else
                indt = @indentStringForLineAtIndex cp[1]
                
            stxt = word.length and salt(word).split('\n') or ['', '', '', '', '']
            stxt = ("#{indt}#{@lineComment} #{s}  " for s in stxt)
            @do.start()
            newCursors = []
            li = cp[1]
            for s in stxt
                @do.insert li, s
                if s.endsWith "#{@lineComment}   "
                    newCursors.push [s.length-2, li]
                else
                    newCursors.push [s.length, li]
                li += 1
            @do.setCursors newCursors, main: 'last'
            @do.select []
            @do.end()
        @setSalterMode true

    endSalter: -> @setSalterMode false
    setSalterMode: (active=true) ->
        @salterMode = active
        @layerDict?['cursors']?.classList.toggle "salterMode", active
    
    insertSalterCharacter: (ch) ->
        if ch == ' '
            char = ['    ', '    ', '    ', '    ', '    ']
        else
            char = salt(ch).split '\n'
        if char.length == 5
            salted = ("#{s}  " for s in char).join '\n'
            @pasteText salted
        else
            @setSalterMode false
        true
    
    deleteSalterCharacter: ->
        return if not @salterMode
        @do.start()
        cp = @do.mainCursor()
        if rgs = @salterRangesAtPos cp
            slt = (@do.textInRange r for r in rgs)
            cols = @columnsInSalt slt
            ci = cols.length-1
            while ci > 0 and cols[ci-1] >= cp[0]
                ci -= 1
            if ci > 0
                length = cols[ci]-cols[ci-1]
                for r in rgs
                    @do.change r[0], @do.line(r[0]).splice cols[ci-1], length
                @do.setCursors ([cols[ci-1], r[0]] for r in rgs)
        @do.end()
    
    checkSalterMode: ->        
        return if not @salterMode
        @setSalterMode false
        return if @do.numCursors() != 5
        cs = @do.cursors()
        cp = cs[0]
        for c in cs.slice 1
            return if c[0] != cp[0]
            return if c[1] != cp[1]+1
            cp = c
        rgs = @salterRangesAtPos @do.mainCursor()
        return if not rgs? or rgs[0][0] != cs[0][1]
        cols = @columnsInSalt (@do.textInRange(r) for r in rgs)
        return if cs[0][0] < cols[0]
        @setSalterMode true
        
    salterRangesAtPos: (p) ->
        salterRegExp = new RegExp("^\\s*#{@lineComment}[0\\s]+$")
        rgs = []
        li = p[1]
        while rgs.length < 5 and li < @do.numLines() and salterRegExp.test @do.line(li)
            rgs.push @do.rangeForLineAtIndex li
            li += 1
        return if not rgs.length
        li = p[1]-1
        while rgs.length < 5 and li >= 0 and salterRegExp.test @do.line(li)
            rgs.unshift @do.rangeForLineAtIndex li
            li -= 1
        return rgs if rgs.length == 5
      
    columnsInSalt: (slt) ->
        min = _.min (s.search /0/ for s in slt)
        if min < 0
            min = _.min (s.search(/#/)+1 for s in slt)
            return [min]
        max = _.max (s.length for s in slt)
        cols = new Set [min, max]
        for col in [min..max]
            s = 0
            for i in [0...5]
                s += 1 if slt[i].substr(col-2, 2) in ['  ', '# ']
            cols = cols.add col if s == 5
        _.sortBy cols.toArray()
