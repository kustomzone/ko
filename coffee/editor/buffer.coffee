# 0000000    000   000  00000000  00000000  00000000  00000000 
# 000   000  000   000  000       000       000       000   000
# 0000000    000   000  000000    000000    0000000   0000000  
# 000   000  000   000  000       000       000       000   000
# 0000000     0000000   000       000       00000000  000   000
{
clamp,
startOf,
endOf,
first,
last
}      = require "../tools/tools"
log    = require '../tools/log'
assert = require 'assert'
event  = require 'events'
_      = require 'lodash'

class Buffer extends event
    
    constructor: () -> @setLines ['']

    setLines: (@lines) ->
        @cursors    = [[0,0]]
        @selections = []
        @highlights = []
        @emit 'numLines', @lines.length

    #  0000000  000   000  00000000    0000000   0000000   00000000    0000000
    # 000       000   000  000   000  000       000   000  000   000  000     
    # 000       000   000  0000000    0000000   000   000  0000000    0000000 
    # 000       000   000  000   000       000  000   000  000   000       000
    #  0000000   0000000   000   000  0000000    0000000   000   000  0000000 
    
    cursorsInLineIndexRangeRelativeToLineIndex: (lineIndexRange, relIndex) ->
        cs = []
        for c in @cursors
            if c[1] >= lineIndexRange[0] and c[1] <= lineIndexRange[1]
                cs.push [c[0], c[1] - relIndex]
        cs
        
    cursorAtPos: (p) ->
        for c in @cursors
            if c[0] == p[0] and c[1] == p[1]
                return c
                
    cursorsInRange: (r) ->
        cs = []
        for c in @cursors
            if @isPosInRange c, r
                cs.push c
        cs
                
    indexOfCursor: (c) -> @cursors.indexOf c

    reversedCursors: ->
        cs = _.clone @cursors
        cs.reverse()
        cs

    cursorsInLineAtIndex: (li) ->
        cs = []
        for c in @cursors
            if c[1] == li
                cs.push c
        cs
    
    cursorAtEndOfLine:   (c=@cursors[0]) -> c[0] >= @lines[c[1]].length
    cursorAtStartOfLine: (c=@cursors[0]) -> c[0] == 0
    cursorInLastLine:    (c=@cursors[0]) -> c[1] == @lines.length-1
    cursorInFirstLine:   (c=@cursors[0]) -> c[1] == 0

    # 000   000   0000000   00000000   0000000  
    # 000 0 000  000   000  000   000  000   000
    # 000000000  000   000  0000000    000   000
    # 000   000  000   000  000   000  000   000
    # 00     00   0000000   000   000  0000000  

    rangeForWordAtPos: (pos) ->
        p = @clampPos pos
        wr = @wordRangesInLineAtIndex p[1]
        r = @rangeAtPosInRanges p, wr
        r

    endOfWordAtCursor: (c=@cursors[0]) =>
        r = @rangeForWordAtPos c
        if @cursorAtEndOfLine c
            return c if @cursorInLastLine c
            r = @rangeForWordAtPos [0, c[1]+1]
        [r[1][1], r[0]]

    startOfWordAtCursor: (c=@cursors[0]) =>
        if @cursorAtStartOfLine c
            return c if @cursorInFirstLine c
            r = @rangeForWordAtPos [@lines[c[1]-1].length, c[1]-1]
        else 
            r = @rangeForWordAtPos c
            if r[1][0] == c[0]
                r = @rangeForWordAtPos [c[0]-1, c[1]]
        [r[1][0], r[0]]
        
    wordRangesInLineAtIndex: (li) ->
        r = []
        re = new RegExp "(\\s+|\\w+|[^\\s])", 'g'
        while (mtch = re.exec(@lines[li])) != null
            r.push [li, [mtch.index, re.lastIndex]]
        r.length and r or [[li, [0,0]]]
       
    nonSpaceRangesInLineAtIndex: (li) ->                        
        r = []
        re = new RegExp "([^\\s]+)", 'g'
        while (mtch = re.exec(@lines[li])) != null
            r.push [li, [mtch.index, re.lastIndex]]
        r.length and r or [[li, [0,0]]]

    #  0000000  00000000  000      00000000   0000000  000000000  000   0000000   000   000   0000000
    # 000       000       000      000       000          000     000  000   000  0000  000  000     
    # 0000000   0000000   000      0000000   000          000     000  000   000  000 0 000  0000000 
    #      000  000       000      000       000          000     000  000   000  000  0000       000
    # 0000000   00000000  0000000  00000000   0000000     000     000   0000000   000   000  0000000 

    selectionsInLineIndexRangeRelativeToLineIndex: (lineIndexRange, relIndex) ->
        sl = @selectionsInLineIndexRange lineIndexRange
        if sl
            ([s[0]-relIndex, [s[1][0], s[1][1]]] for s in sl)
    
    selectionsInLineIndexRange: (lineIndexRange) ->
        sl = []
        for s in @selections
            if s[0] >= lineIndexRange[0] and s[0] <= lineIndexRange[1]
                sl.push _.clone s
        sl
        
    reversedSelections: ->
        sl = _.clone @selections
        sl.reverse()
        sl

    selectedLineIndices: -> _.uniq (s[0] for s in @selections)
    cursorLineIndices:   -> _.uniq (c[1] for c in @cursors)

    cursorAndSelectedLineIndices: ->
        _.uniq @selectedLineIndices().concat @cursorLineIndices()
                
    selectedLineIndicesRange: ->
        if @selections.length
            [first(@selections)[0], last(@selections)[0]]
        else
            []
            
    isSelectedLineAtIndex: (li) ->
        il = @selectedLineIndices()
        if li in il
            s = @selections[il.indexOf li]
            if s[1][0] == 0 and s[1][1] == @lines[li].length
                return true
        false
        
    selectionsInLineAtIndex: (li) ->
        sl = []
        for s in @selections
            if s[0] == li
                sl.push s
        sl
        
    indexOfSelection: (s) -> @selections.indexOf s
    
    startPosOfContinuousSelectionAtPos: (p) ->
        r = @rangeAtPosInRanges p, @selections
        if r
            sp = @rangeStartPos r
            while (sp[0] == 0) and (sp[1] > 0)
                plr = @rangeForLineAtIndex sp[1]-1
                r = @rangeAtPosInRanges @rangeEndPos(plr), @selections
                if r
                    sp = @rangeStartPos plr
                else
                    break
        sp

    # 000   000  000   0000000   000   000  000      000   0000000   000   000  000000000   0000000
    # 000   000  000  000        000   000  000      000  000        000   000     000     000     
    # 000000000  000  000  0000  000000000  000      000  000  0000  000000000     000     0000000 
    # 000   000  000  000   000  000   000  000      000  000   000  000   000     000          000
    # 000   000  000   0000000   000   000  0000000  000   0000000   000   000     000     0000000 

    highlightsInLineIndexRangeRelativeToLineIndex: (lineIndexRange, relIndex) ->
        hl = @highlightsInLineIndexRange lineIndexRange
        if hl
            ([s[0]-relIndex, [s[1][0], s[1][1]]] for s in hl)
    
    highlightsInLineIndexRange: (lineIndexRange) ->
        hl = []
        for s in @highlights
            if s[0] >= lineIndexRange[0] and s[0] <= lineIndexRange[1]
                hl.push _.clone s
        hl
        
    reversedHighlights: ->
        r = _.clone @highlights
        r.reverse()
        r
        
    posInHighlights: (p) -> @highlights.length and @rangeAtPosInRanges p, @highlights
                    
    # 000000000  00000000  000   000  000000000
    #    000     000        000 000      000   
    #    000     0000000     00000       000   
    #    000     000        000 000      000   
    #    000     00000000  000   000     000   

    text:            -> @lines.join '\n'
    textInRange: (r) -> @lines[r[0]].slice r[1][0], r[1][1]
        
    # 000  000   000  0000000    00000000  000   000  000000000
    # 000  0000  000  000   000  000       0000  000     000   
    # 000  000 0 000  000   000  0000000   000 0 000     000   
    # 000  000  0000  000   000  000       000  0000     000   
    # 000  000   000  0000000    00000000  000   000     000   
        
    indentationAtLineIndex: (i) ->
        s = 0
        while @lines[i][s] == ' '
            s += 1
        s
            
    # 00000000    0000000    0000000
    # 000   000  000   000  000     
    # 00000000   000   000  0000000 
    # 000        000   000       000
    # 000         0000000   0000000 
    
    lastPos: () -> 
        lli = @lines.length-1
        [@lines[lli].length, lli]

    cursorPos: -> # todo: last cursor
        l = clamp 0, @lines.length-1, @cursors[0][1]
        c = clamp 0, @lines[l].length, @cursors[0][0]
        [ c, l ]
        
    clampPos: (p) ->
        l = clamp 0, @lines.length-1, p[1]
        c = clamp 0, @lines[l].length, p[0]
        [ c, l ]
        
    isPosInRange: (p, r) ->
        return (p[1] == r[0]) and (r[1][0] <= p[0] <= r[1][1])
        
    positionsFromPosInPositions: (p, pl) -> 
        (r for r in pl when ((r[1] > p[1]) or ((r[1] == p[1]) and (r[0] >= p[0]))))
    positionsInLineAtIndexInPositions: (li,pl) -> (p for p in pl when p[1] == li)
    positionsBelowLineIndexInPositions: (li,pl) -> (p for p in pl when p[1] > li)

    # 00000000    0000000   000   000   0000000   00000000
    # 000   000  000   000  0000  000  000        000     
    # 0000000    000000000  000 0 000  000  0000  0000000 
    # 000   000  000   000  000  0000  000   000  000     
    # 000   000  000   000  000   000   0000000   00000000

    rangeEndPos:   (r)   -> [r[1][1], r[0]]
    rangeStartPos: (r)   -> [r[1][0], r[0]]
    rangeIndexPos: (r,i) -> [r[1][i], r[0]]
    rangeForPos: (p) -> [p[1], [p[0], p[0]]]
    rangeForLineAtIndex: (i) -> 
        throw new Error() if i >= @lines.length
        [i, [0, @lines[i].length]] 

    isRangeInString: (r) -> @rangeOfStringSurroundingRange(r)?
   
    rangeOfInnerStringSurroundingRange: (r) ->
        rgs = @rangesOfStringsInLineAtIndex r[0]
        rgs = @rangesShrunkenBy rgs, 1
        @rangeContainingRangeInRanges r, rgs
        
    rangeOfStringSurroundingRange: (r) ->
        if ir = @rangeOfInnerStringSurroundingRange r
            @rangeGrownBy ir, 1
            
    rangeGrownBy: (r,delta) -> [r[0], [r[1][0]-delta, r[1][1]+delta]]

    # 00000000    0000000   000   000   0000000   00000000   0000000
    # 000   000  000   000  0000  000  000        000       000     
    # 0000000    000000000  000 0 000  000  0000  0000000   0000000 
    # 000   000  000   000  000  0000  000   000  000            000
    # 000   000  000   000  000   000   0000000   00000000  0000000 
    
    rangesBetweenPositions: (a, b) ->
        r = []
        [a,b] = @sortPositions [a,b]
        if a[1] == b[1]
            r.push [a[1], [a[0], b[0]]]
        else
            r.push [a[1], [a[0], @lines[a[1]].length]]
            r.push [b[1], [0, b[0]]]
        if b[1] - a[1] > 1
            for i in [a[1]+1...b[1]]
                r.push [i, [0,@lines[i].length]]
        r
    
    rangesForCursors: (cs=@cursors) -> ([c[1], [c[0], c[0]]] for c in cs)
                   
    rangesForAllLines: -> @rangesForLinesFromTopToBot 0, @lines.length
    
    rangesForLinesFromTopToBot: (top,bot) -> 
        r = []
        ir = [top,bot]
        for li in [startOf(ir)...endOf(ir)]
            r.push @rangeForLineAtIndex li
        r
    
    rangesForTextInLineAtIndex: (t, i, opt) ->
        s = 'i'
        s = '' if opt?.caseSensitive
        re = new RegExp t, 'g' + s
        r = []
        while (mtch = re.exec(@lines[i])) != null
            r.push [i, [mtch.index, re.lastIndex]]
        r
                    
    rangesForText: (t, opt) ->
        t = t.split('\n')[0]
        r = []
        for li in [0...@lines.length]
            r = r.concat @rangesForTextInLineAtIndex t, li, opt
        r        
      
    rangesOfStringsInLineAtIndex: (li) -> # todo: handle #{}
        t = @lines[li]
        r = []
        ss = -1
        cc = null
        for i in [0...t.length]
            c = t[i]
            if not cc and c in "'\""
                cc = c
                ss = i
            else if c == cc
                if (t[i-1] != '\\') or (i>2 and t[i-2] == '\\')
                    r.push [li, [ss, i+1]]
                    cc = null
                    ss = -1
        r
      
    # 000  000   000        00000000    0000000   000   000   0000000   00000000   0000000
    # 000  0000  000        000   000  000   000  0000  000  000        000       000     
    # 000  000 0 000        0000000    000000000  000 0 000  000  0000  0000000   0000000 
    # 000  000  0000        000   000  000   000  000  0000  000   000  000            000
    # 000  000   000        000   000  000   000  000   000   0000000   00000000  0000000 
      
    rangesForLineIndexInRanges: (li, ranges) -> (r for r in ranges when r[0]==li)
    
    rangeAtPosInRanges: (pos, ranges) ->
        return if ranges.length == 0
        for ri in [ranges.length-1..0]
            r = ranges[ri]
            if (r[0] == pos[1]) and (r[1][0] <= pos[0] <= r[1][1])
                return r
            
    rangeBeforePosInRanges: (pos, ranges) ->
        return if ranges.length == 0
        for ri in [ranges.length-1..0]
            r = ranges[ri]
            if (r[0] < pos[1]) or ((r[0] == pos[1]) and (r[1][1] < pos[0]))
                return r 
    
    rangeAfterPosInRanges: (pos, ranges) ->
        for r in ranges
            if (r[0] > pos[1]) or ((r[0] == pos[1]) and (r[1][0] > pos[0]))
                return r
    
    rangeStartingOrEndingAtPosInRanges: (p, ranges) ->
        return if ranges.length == 0
        for ri in [ranges.length-1..0]
            r = ranges[ri]
            if r[0] == p[1]
                if r[1][0] == p[0] or r[1][1] == p[0]
                    return r
    
    rangesFromTopToBotInRanges: (top, bot, ranges) ->
        (r for r in ranges when top <= r[0] <= bot)
        
    rangeContainingRangeInRanges: (r, ranges) ->
        if cr = @rangeAtPosInRanges @rangeStartPos(r), ranges
            return cr if cr[1][1] >= r[1][1]
        
    sortedLineIndicesInRanges: (ranges) -> _.uniq(s[0] for s in ranges).sort (a,b)->(a-b)
    
    rangesShrunkenBy: (ranges, delta) ->
        ([r[0], [r[1][0]+delta, r[1][1]-delta]] for r in ranges when (r[1][1]-r[1][0])>=2*delta)
                             
    # 000   000  000   000  000   000   0000000  00000000  0000000    00000 
    # 000   000  0000  000  000   000  000       000       000   000     000
    # 000   000  000 0 000  000   000  0000000   0000000   000   000   000  
    # 000   000  000  0000  000   000       000  000       000   000        
    #  0000000   000   000   0000000   0000000   00000000  0000000     000  
    
    rangeIntersection: (a,b) ->
        s = Math.max(a[0], b[0])
        e = Math.min(a[1], b[1])
        [s, e] if s<=e
        
    #  0000000   0000000   00000000   000000000
    # 000       000   000  000   000     000   
    # 0000000   000   000  0000000       000   
    #      000  000   000  000   000     000   
    # 0000000    0000000   000   000     000   
                
    sortRanges: (ranges) ->
        ranges.sort (a,b) -> 
            if a[0]!=b[0]
                a[0]-b[0]
            else
                if a[1][0]!=b[1][0]
                    a[1][0]-b[1][0]
                else
                    a[1][1]-b[1][1]
                    
    sortPositions: (positions) ->
        positions.sort (a,b) ->
            if a[1]!=b[1]
                a[1]-b[1]
            else
                a[0]-b[0]
                
    #  0000000  000       0000000   00     00  00000000 
    # 000       000      000   000  000   000  000   000
    # 000       000      000000000  000000000  00000000 
    # 000       000      000   000  000 0 000  000      
    #  0000000  0000000  000   000  000   000  000      
                
    clampPositions: (positions) ->
        for p in positions
            p[0] = Math.max p[0], 0
            p[1] = clamp 0, @lines.length-1, p[1]
           
    #  0000000  000      00000000   0000000   000   000
    # 000       000      000       000   000  0000  000
    # 000       000      0000000   000000000  000 0 000
    # 000       000      000       000   000  000  0000
    #  0000000  0000000  00000000  000   000  000   000
              
    cleanCursors: (cs) ->
        @clampPositions cs
        @sortPositions cs
        if cs.length > 1
            for ci in [cs.length-1...0]
                c = cs[ci]
                p = cs[ci-1]
                if c[1] == p[1] and c[0] == p[0] 
                    cs.splice ci, 1
        cs
                    
    cleanRanges: (ranges) ->
        @sortRanges ranges 
        if ranges.length > 1
            for ri in [ranges.length-1...0]
                r = ranges[ri]
                p = ranges[ri-1]
                if r[0] == p[0] # on same line
                    if r[1][0] <= p[1][1] # starts before previous ends
                        p[1][1] = Math.max(p[1][1], r[1][1])
                        ranges.splice ri, 1
        ranges
    
module.exports = Buffer
