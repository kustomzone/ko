# 000   000  000  00000000  000   000  0000000     0000000    0000000  00000000
# 000   000  000  000       000 0 000  000   000  000   000  000       000     
#  000 000   000  0000000   000000000  0000000    000000000  0000000   0000000 
#    000     000  000       000   000  000   000  000   000       000  000     
#     0      000  00000000  00     00  0000000    000   000  0000000   00000000
{
characterWidth,
setStyle,
clamp,
last,
$}         = require '../tools/tools'
prefs      = require '../tools/prefs'
drag       = require '../tools/drag'
keyinfo    = require '../tools/keyinfo'
log        = require '../tools/log'
str        = require '../tools/str'
render     = require './render'
syntax     = require './syntax'
scroll     = require './scroll'
Editor     = require './editor'
_          = require 'lodash'
electron   = require 'electron'
clipboard  = electron.clipboard

class ViewBase extends Editor

    # 000  000   000  000  000000000
    # 000  0000  000  000     000   
    # 000  000 0 000  000     000   
    # 000  000  0000  000     000   
    # 000  000   000  000     000   

    constructor: (viewElem, @config) ->
        @name = viewElem
        @name = @name.slice 1 if @name[0] == '.'
        @view = $(viewElem)
        @view.onpaste = (event) => log "view on paste #{@name}", event
        @view.onblur  = (event) => @emit 'blur', @
        @view.onfocus = (event) => @emit 'focus', @
        layer = []
        layer.push 'selections' 
        layer.push 'highlights' 
        layer.push 'meta'         if 'Meta'    in @config.features
        layer.push 'lines' 
        layer.push 'cursors'
        layer.push 'numbers'      if 'Numbers' in @config.features
        @initLayers layer
        @elem = $('.lines', @view)
        @diss = []
        @size = {}
        @syntax = new syntax @
                
        @setFontSize prefs.get "#{@name}FontSize", @fontSizeDefault

        @scroll = new scroll 
            lineHeight: @size.lineHeight
            viewHeight: @viewHeight()
            
        @scroll.on 'clearLines', @clearLines
        @scroll.on 'exposeTop',  @exposeTop
        @scroll.on 'exposeLine', @exposeLine
        @scroll.on 'vanishLine', @vanishLine

        @view.onkeydown = @onKeyDown
        @initDrag()    
        
        super
        
        # 00000000  00000000   0000000   000000000  000   000  00000000   00000000   0000000
        # 000       000       000   000     000     000   000  000   000  000       000     
        # 000000    0000000   000000000     000     000   000  0000000    0000000   0000000 
        # 000       000       000   000     000     000   000  000   000  000            000
        # 000       00000000  000   000     000      0000000   000   000  00000000  0000000 
        
        for feature in @config.features
            featureName = feature.toLowerCase()
            featureClss = require "./#{featureName}"
            @[featureName] = new featureClss @                
            
    # 000       0000000   000   000  00000000  00000000    0000000
    # 000      000   000   000 000   000       000   000  000     
    # 000      000000000    00000    0000000   0000000    0000000 
    # 000      000   000     000     000       000   000       000
    # 0000000  000   000     000     00000000  000   000  0000000 
    
    initLayers: (layerClasses) ->
        @layers = {}
        for cls in layerClasses
            @layers[cls] = @addLayer cls
        
    addLayer: (cls) ->
        div = document.createElement 'div'
        div.className = cls
        @view.appendChild div
        div
        
    updateLayers: () ->
        @renderHighlights()
        @renderSelection()
        @renderCursors()

    #  0000000  00000000  000000000        000000000  00000000  000   000  000000000
    # 000       000          000              000     000        000 000      000   
    # 0000000   0000000      000              000     0000000     00000       000   
    #      000  000          000              000     000        000 000      000   
    # 0000000   00000000     000              000     00000000  000   000     000   
    
    setText: (text) ->
        if @syntax.name == 'txt'
            if text.startsWith "#!"
                firstLine = text.slice 0, text.search /\r?\n/
                lastWord = last firstLine.split ' '
                switch lastWord
                    when 'python'      then @syntax.name = 'py'
                    when 'node'        then @syntax.name = 'js'
                    when 'bash', 'sh'  then @syntax.name = 'sh'
                    else 
                        if lastWord in syntax.syntaxNames
                            @syntax.name = lastWord
        super text
                
    #  0000000  00000000  000000000  000      000  000   000  00000000   0000000
    # 000       000          000     000      000  0000  000  000       000     
    # 0000000   0000000      000     000      000  000 0 000  0000000   0000000 
    #      000  000          000     000      000  000  0000  000            000
    # 0000000   00000000     000     0000000  000  000   000  00000000  0000000 

    setLines: (lines) ->
        # log "viewbase.setLines lines", lines if @name == 'editor'        
        if lines.length == 0
            @scroll.reset() 
        
        lines ?= ['']
        super lines
        @syntax.clear()      
        if @scroll.viewHeight != @viewHeight()
            @scroll.setViewHeight @viewHeight()
            @emit 'viewHeight', @viewHeight()
        @scroll.setNumLines @lines.length
        @view.scrollLeft = 0
        @updateScrollOffset()
        @updateLayers()

    #  0000000   00000000   00000000   00000000  000   000  0000000          000000000  00000000  000   000  000000000
    # 000   000  000   000  000   000  000       0000  000  000   000           000     000        000 000      000   
    # 000000000  00000000   00000000   0000000   000 0 000  000   000           000     0000000     00000       000   
    # 000   000  000        000        000       000  0000  000   000           000     000        000 000      000   
    # 000   000  000        000        00000000  000   000  0000000             000     00000000  000   000     000   
    
    appendText: (text) ->
        
        ts = text?.split /\n/
        for t in ts
            @lines.push t
            @emit 'lineAppended', 
                lineIndex: @lines.length-1
                text: t
        if @scroll.viewHeight != @viewHeight()
            @scroll.setViewHeight @viewHeight()        
        @scroll.setNumLines @lines.length
        @emit  'linesAppended', ts
        @emit 'numLines', @lines.length

    # 00000000   0000000   000   000  000000000   0000000  000  0000000  00000000
    # 000       000   000  0000  000     000     000       000     000   000     
    # 000000    000   000  000 0 000     000     0000000   000    000    0000000 
    # 000       000   000  000  0000     000          000  000   000     000     
    # 000        0000000   000   000     000     0000000   000  0000000  00000000

    setFontSize: (fontSize) =>
        # log "viewbase.setFontSize className #{@view.className} size #{fontSize}"
        @view.style.fontSize = "#{fontSize}px"
        @size.numbersWidth = 'Numbers' in @config.features and 50 or 0
        @size.fontSize     = fontSize
        @size.lineHeight   = fontSize + Math.floor(fontSize/6)
        @size.charWidth    = fontSize * 0.6 # characterWidth @elem, 'line'
        @size.offsetX      = Math.floor @size.charWidth/2 + @size.numbersWidth

        @scroll?.setLineHeight @size.lineHeight
            
        @emit 'fontSizeChanged'

    #  0000000   0000000    0000000    000      000  000   000  00000000
    # 000   000  000   000  000   000  000      000  0000  000  000     
    # 000000000  000   000  000   000  000      000  000 0 000  0000000 
    # 000   000  000   000  000   000  000      000  000  0000  000     
    # 000   000  0000000    0000000    0000000  000  000   000  00000000
    
    addLine: ->
        div = document.createElement 'div'
        div.className = 'line'
        div.style.height = "#{@size.lineHeight}px"
        y = @elem.children.length * @size.lineHeight
        div.style.transform = "translate(#{@size.offsetX}px,#{y}px)"
        div    

    #  0000000  000   000   0000000   000   000   0000000   00000000  0000000  
    # 000       000   000  000   000  0000  000  000        000       000   000
    # 000       000000000  000000000  000 0 000  000  0000  0000000   000   000
    # 000       000   000  000   000  000  0000  000   000  000       000   000
    #  0000000  000   000  000   000  000   000   0000000   00000000  0000000  
  
    done: => @changed @do.changeInfo
    
    changed: (changeInfo) ->
        # log "viewbase.changed .. #{changeInfo.sorted}" if changeInfo.sorted.length
        @syntax.changed changeInfo
        
        numChanges = 0   
        changes = _.cloneDeep changeInfo.sorted    
        while (change = changes.shift())
            [li,ch,oi] = change
            # log "viewbase.changed li #{li} change #{ch} oi #{oi} @lines[li] #{@lines[li]} diss", @syntax.getDiss li
            switch ch
                when 'changed' 
                    @updateLine li, oi
                    @emit 'lineChanged', li
                when 'deleted'  
                    numChanges -= 1 
                    @deleteLine li, oi
                when 'inserted' 
                    numChanges += 1
                    @insertLine li, oi
              
        if numChanges != 0 
            @updateLinePositions()

        @scroll.setNumLines @lines.length
        @scrollBy 0
            
        if changeInfo.cursors.length
            @renderCursors()
            if delta = @deltaToEnsureCursorsAreVisible()
                @scrollBy delta * @size.lineHeight - @scroll.offsetSmooth 
            $('.main', @view)?.scrollIntoViewIfNeeded()
            @updateScrollOffset()
            @emit 'cursor'
            
        if changeInfo.selection.length
            @renderSelection()   
            @emit 'selection'

        @renderHighlights()
        @emit 'changed', changeInfo

    # 0000000    00000000  000      00000000  000000000  00000000
    # 000   000  000       000      000          000     000     
    # 000   000  0000000   000      0000000      000     0000000 
    # 000   000  000       000      000          000     000     
    # 0000000    00000000  0000000  00000000     000     00000000

    deleteLine: (li, oi) ->
        @elem.children[oi - @scroll.exposeTop]?.remove()
        @scroll.deleteLine li, oi
        @emit 'lineDeleted', oi
        
    # 000  000   000   0000000  00000000  00000000   000000000
    # 000  0000  000  000       000       000   000     000   
    # 000  000 0 000  0000000   0000000   0000000       000   
    # 000  000  0000       000  000       000   000     000   
    # 000  000   000  0000000   00000000  000   000     000   
        
    insertLine: (li, oi) ->        
        div = @addLine()
        div.innerHTML = @renderLineAtIndex li
        @elem.insertBefore div, @elem.children[oi - @scroll.exposeTop]
        @scroll.insertLine li, oi
        @emit 'lineInserted', li
        
    # 00000000  000   000  00000000    0000000    0000000  00000000
    # 000        000 000   000   000  000   000  000       000     
    # 0000000     00000    00000000   000   000  0000000   0000000 
    # 000        000 000   000        000   000       000  000     
    # 00000000  000   000  000         0000000   0000000   00000000

    exposeLine: (li) =>
        html = @renderLineAtIndex li
        lineDiv = @addLine()
        lineDiv.innerHTML = html
        @elem.appendChild lineDiv
        
        if li != @elem.children.length-1+@scroll.exposeTop 
            console.log "viewbase.exposeLine wtf? #{li} != #{@elem.children.length-1+@scroll.exposeTop }"
        
        @emit 'lineExposed', 
            lineIndex: li
            lineDiv: lineDiv

        @renderCursors() if @cursorsInLineAtIndex(li).length
        @renderSelection() if @rangesForLineIndexInRanges(li, @selections).length
        @renderHighlights() if @rangesForLineIndexInRanges(li, @highlights).length
        lineDiv
        
    # 000   000   0000000   000   000  000   0000000  000   000
    # 000   000  000   000  0000  000  000  000       000   000
    #  000 000   000000000  000 0 000  000  0000000   000000000
    #    000     000   000  000  0000  000       000  000   000
    #     0      000   000  000   000  000  0000000   000   000
    
    vanishLine: (li) =>
        if (not li?) or (li < 0 )
            li = @elem.children.length-1
        if li == @scroll.exposeTop + @elem.children.length - 1
            @elem.lastChild?.remove()
            @emit 'lineVanished', 
                lineIndex: li
        else
            log "warning! viewbase.vanishLine wrong line index? li: #{li} children: #{@elem.children.length}"

    # 00000000  000   000  00000000    0000000    0000000  00000000  000000000   0000000   00000000 
    # 000        000 000   000   000  000   000  000       000          000     000   000  000   000
    # 0000000     00000    00000000   000   000  0000000   0000000      000     000   000  00000000 
    # 000        000 000   000        000   000       000  000          000     000   000  000      
    # 00000000  000   000  000         0000000   0000000   00000000     000      0000000   000      

    exposeTop: (e) =>
        # log "viewbase.exposeTopChange #{e.old} -> #{e.new}"
        num = Math.abs e.num

        for n in [0...num]
            if e.num < 0
                @elem.firstChild.remove()
                li = e.new - (num - n)
                
                @emit 'lineVanishedTop', 
                    lineIndex: li
                
            else 
                div = @addLine()
                li = e.new + num - n - 1
                div.innerHTML = @renderLineAtIndex li
                @elem.insertBefore div, @elem.firstChild
                
                @emit 'lineExposedTop', 
                    lineIndex: li
                    lineDiv: div
             
        @updateLinePositions()
        @updateLayers()            
        @emit 'exposeTopChanged', e            
                           
    # 000   000  00000000   0000000     0000000   000000000  00000000
    # 000   000  000   000  000   000  000   000     000     000     
    # 000   000  00000000   000   000  000000000     000     0000000 
    # 000   000  000        000   000  000   000     000     000     
    #  0000000   000        0000000    000   000     000     00000000

    updateLinePositions: () ->
        y = 0
        for c in @elem.children
            c.style.transform = "translate(#{@size.offsetX}px,#{y}px)"
            y += @size.lineHeight
                
    updateLine: (li, oi) ->
        if @scroll.exposeTop <= li < @lines.length
            span = @renderLineAtIndex li
            @elem.children[oi - @scroll.exposeTop]?.innerHTML = span

    # 00000000   00000000  000   000  0000000    00000000  00000000 
    # 000   000  000       0000  000  000   000  000       000   000
    # 0000000    0000000   000 0 000  000   000  0000000   0000000  
    # 000   000  000       000  0000  000   000  000       000   000
    # 000   000  00000000  000   000  0000000    00000000  000   000
            
    renderLineAtIndex: (li) -> render.line @lines[li], @syntax.getDiss li
                                                    
    renderCursors: ->
        cs = []
        for c in @cursors
            if c[1] >= @scroll.exposeTop and c[1] <= @scroll.exposeBot
                cs.push [c[0], c[1] - @scroll.exposeTop]
        
        if @cursors.length == 1
            if cs.length == 1
                ri = @mainCursor[1]-@scroll.exposeTop
                if @mainCursor[0] > @lines[@mainCursor[1]].length
                    cs[0][2] = 'virtual'
                    cs.push [@lines[@mainCursor[1]].length, ri, 'main off']
                else
                    cs[0][2] = 'main off'
        else if @cursors.length > 1
            vc = [] # virtual cursors
            for c in cs
                if @isMainCursor [c[0], c[1] + @scroll.exposeTop]
                    c[2] = 'main'
                if c[0] > @lines[@scroll.exposeTop+c[1]].length
                    vc.push [@lines[@scroll.exposeTop+c[1]].length, c[1], 'virtual']
            cs = cs.concat vc
        html = render.cursors cs, @size
        $('.cursors', @view).innerHTML = html
            
    renderSelection: ->
        h = ""
        s = @selectionsInLineIndexRangeRelativeToLineIndex [@scroll.exposeTop, @scroll.exposeBot], @scroll.exposeTop
        if s
            h += render.selection s, @size
        $('.selections', @view).innerHTML = h

    renderHighlights: ->
        h = ""
        s = @highlightsInLineIndexRangeRelativeToLineIndex [@scroll.exposeTop, @scroll.exposeBot], @scroll.exposeTop
        if s
            h += render.selection s, @size, "highlight"
        $('.highlights', @view).innerHTML = h

    # 00000000   00000000   0000000  000  0000000  00000000  0000000  
    # 000   000  000       000       000     000   000       000   000
    # 0000000    0000000   0000000   000    000    0000000   000   000
    # 000   000  000            000  000   000     000       000   000
    # 000   000  00000000  0000000   000  0000000  00000000  0000000  
    
    resized: -> 
        @scroll?.setViewHeight @viewHeight()
        @numbers?.elem.style.height = "#{@viewHeight}px"
        @updateScrollOffset()
        # log "viewbase.resized emit viewHeight #{@viewHeight()}"
        @emit 'viewHeight', @viewHeight()
    
    deltaToEnsureCursorsAreVisible: ->
        topdelta = 0
        cl = @cursors[0][1]
        if cl < @scroll.top + 2
            topdelta = Math.max(0, cl - 2) - @scroll.top
        else if cl > @scroll.bot - 4
            topdelta = Math.min(@lines.length+1, cl + 4) - @scroll.bot
        
        botdelta = 0
        cl = last(@cursors)[1]
        if cl < @scroll.top + 2
            botdelta = Math.max(0, cl - 2) - @scroll.top
        else if cl > @scroll.bot - 4
            botdelta = Math.min(@lines.length+1, cl + 4) - @scroll.bot
            
        maindelta = 0
        cl = @mainCursor[1]
        if cl < @scroll.top + 2
            maindelta = Math.max(0, cl - 2) - @scroll.top
        else if cl > @scroll.bot - 4
            maindelta = Math.min(@lines.length+1, cl + 4) - @scroll.bot
            
        maindelta

    #  0000000   0000000  00000000    0000000   000      000    
    # 000       000       000   000  000   000  000      000    
    # 0000000   000       0000000    000   000  000      000    
    #      000  000       000   000  000   000  000      000    
    # 0000000    0000000  000   000   0000000   0000000  0000000
                        
    scrollLines: (delta) -> @scrollBy delta * @size.lineHeight

    scrollBy: (delta, x) -> 
        @scroll.by delta
        @view.scrollLeft += x/2
        @updateScrollOffset()
        
    scrollTo: (p) -> 
        @scroll.to p
        @updateScrollOffset()

    scrollCursorToTop: (topDist=7) ->
        cp = @cursorPos()
        # log "viewbase.scrollCursorToTop #{cp[1]} #{cp[1] - @scroll.top}"
        if cp[1] - @scroll.top > topDist
            rg = [@scroll.top, Math.max 0, cp[1]-1]
            sl = @selectionsInLineIndexRange rg
            hl = @highlightsInLineIndexRange rg
            if sl.length == 0 == hl.length
                delta = @scroll.lineHeight * (cp[1] - @scroll.top - topDist)
                # log "viewbase.scrollCursorToTop #{delta}"
                @scrollBy delta
                @numbers?.updateColors()

    updateScrollOffset: ->
        @view.scrollTop = @scroll.offsetTop
        @numbers?.elem.style.left = "#{@view.scrollLeft}px"
        @numbers?.elem.style.background = @view.scrollLeft and '#000' or "rgba(0,0,0,0.5)"

    # 00000000    0000000    0000000
    # 000   000  000   000  000     
    # 00000000   000   000  0000000 
    # 000        000   000       000
    # 000         0000000   0000000 
    
    posAtXY:(x,y) ->
    
        sl = @view.scrollLeft
        st = @view.scrollTop
        br = @view.getBoundingClientRect()
        lx = clamp 0, @view.offsetWidth,  x - br.left - @size.offsetX + @size.charWidth/3
        ly = clamp 0, @view.offsetHeight, y - br.top
        px = parseInt(Math.floor((Math.max(0, sl + lx))/@size.charWidth))
        py = parseInt(Math.floor((Math.max(0, st + ly))/@size.lineHeight)) + @scroll.exposeTop
        p = [px, Math.min(@lines.length-1, py)]
        p
        
    posForEvent: (event) -> @posAtXY event.clientX, event.clientY

    lineElemAtXY:(x,y) -> 
        p = @posAtXY x,y
        ci = p[1]-@scroll.exposeTop
        @layers['lines'].children[ci]
        
    lineSpanAtXY:(x,y) -> # not used ?
        lineElem = @lineElemAtXY x,y        
        if lineElem?
            lr = lineElem.getBoundingClientRect()
            for e in lineElem.children
                br = e.getBoundingClientRect()
                if br.left <= x and br.left+br.width >= x
                    offset = x-br.left
                    info =  
                        span:       e
                        offsetLeft: offset
                        offsetChar: parseInt offset/@size.charWidth
                    return info
        log "not found! #{x} #{y} line #{lineElem?}"
        null

    # 000      000  000   000  00000000   0000000
    # 000      000  0000  000  000       000     
    # 000      000  000 0 000  0000000   0000000 
    # 000      000  000  0000  000            000
    # 0000000  000  000   000  00000000  0000000 
    
    viewHeight:      -> @view?.getBoundingClientRect().height 
    numViewLines:    -> Math.ceil(@viewHeight() / @size.lineHeight)
    numFullLines:    -> Math.floor(@viewHeight() / @size.lineHeight)
    
    clearLines: => 
        @elem.innerHTML = ""
        @emit 'clearLines'

    clear: => @setLines ['']
        
    focus: -> @view.focus()

    # 00     00   0000000   000   000   0000000  00000000
    # 000   000  000   000  000   000  000       000     
    # 000000000  000   000  000   000  0000000   0000000 
    # 000 0 000  000   000  000   000       000  000     
    # 000   000   0000000    0000000   0000000   00000000

    initDrag: ->
        @drag = new drag
            target:  @view
            cursor:  'default'
            onStart: (drag, event) =>
                                
                if @doubleClicked
                    if @posForEvent(event)[1] == @tripleClickLineIndex
                        clearTimeout @tripleClickTimer                        
                        @tripleClickTimer = setTimeout @onTripleClickDelay, 1500
                        if not @tripleClicked
                            @tripleClicked = true
                            r = @rangeForLineAtIndex @tripleClickLineIndex
                            if event.metaKey
                                @addRangeToSelection r
                            else
                                @selectSingleRange r
                        return
                    else if @tripleClickTimer
                        @onTripleClickDelay()
                        
                @view.focus()
                p = @posForEvent event
                if event.metaKey
                    @toggleCursorAtPos p
                else
                    @singleCursorAtPos p, event.shiftKey
            
            onMove: (drag, event) => 
                p = @posForEvent event
                if event.metaKey
                    @addCursorAtPos [@mainCursor[0], p[1]]  # todo: nearest cursor instead of last
                else
                    @singleCursorAtPos p, true
                
        @view.ondblclick = (event) =>
            range = @rangeForWordAtPos @posForEvent event
            if event.metaKey
                @addRangeToSelection range
            else
                @selectSingleRange range
            @onTripleClickDelay()
            @doubleClicked = true
            @tripleClickTimer = setTimeout @onTripleClickDelay, 1500
            @tripleClickLineIndex = range[0]
                        
    onTripleClickDelay: => 
        clearTimeout @tripleClickTimer
        @tripleClickTimer = null
        @tripleClickLineIndex = -1
        @doubleClicked = @tripleClicked = false
        
    # 000   000  00000000  000   000
    # 000  000   000        000 000 
    # 0000000    0000000     00000  
    # 000  000   000          000   
    # 000   000  00000000     000   

    onKeyDown: (event) =>
        {mod, key, combo} = keyinfo.forEvent event

        # log "viewbase key:", key, "mod:", mod, "combo:", combo

        return if not combo
        return if key == 'right click' # weird right command key

        if @autocomplete?
            if 'unhandled' != @autocomplete.handleModKeyComboEvent mod, key, combo, event
                return
        
        if @handleModKeyComboEvent?
            if 'unhandled' != @handleModKeyComboEvent mod, key, combo, event
                return
            
        switch combo
            when 'tab'                      then return @insertTab() + event.preventDefault() 
            when 'shift+tab'                then return @deleteTab() + event.preventDefault()
            when 'enter'                    then return @insertNewline indent: true
            when 'command+enter'            then return @moveCursorsToLineBoundary('right') and @insertNewline indent: true
            when 'command+]'                then return @indent()
            when 'command+['                then return @deIndent()
            when 'command+j'                then return @joinLines()
            when 'command+/'                then return @toggleComment()
            when 'command+a'                then return @selectAll()
            when 'command+shift+a'          then return @selectNone()
            when 'command+e'                then return @highlightTextOfSelectionOrWordAtCursor()
            when 'command+d'                then return @highlightWordAndAddToSelection()
            when 'command+shift+d'          then return @removeSelectedHighlight()
            when 'command+alt+d'            then return @selectAllHighlights()
            when 'command+g'                then return @selectNextHighlight()
            when 'command+shift+g'          then return @selectPrevHighlight()
            when 'command+l'                then return @selectMoreLines()
            when 'command+shift+l'          then return @selectLessLines()            
            when 'command+c'                then return clipboard.writeText @textOfSelectionForClipboard()
            when 'command+z'                then return @do.undo()
            when 'command+shift+z'          then return @do.redo()
            when 'delete', 'ctrl+backspace' then return @deleteForward()     
            when 'backspace'                then return @deleteBackward()     
            when 'command+v'                then return @paste clipboard.readText()
            when 'command+x'   
                @do.start()
                clipboard.writeText @textOfSelectionForClipboard()
                @deleteSelection()
                @do.end()
                return
                
            when 'alt+up',     'alt+down'     then return @moveLines  key
            when 'command+up', 'command+down' then return @addCursors key
            when 'ctrl+a', 'ctrl+shift+a'     then return @moveCursorsToLineBoundary 'left',  event.shiftKey
            when 'ctrl+e', 'ctrl+shift+e'     then return @moveCursorsToLineBoundary 'right', event.shiftKey
                
            when 'command+left', 'command+right'   
                if @selections.length > 1 and @cursors.length == 1
                    return @setCursorsAtSelectionBoundary key
                else
                    return @moveCursorsToLineBoundary key
                        
            when 'command+shift+left', 'command+shift+right'   
                    return @moveCursorsToLineBoundary key, true
                    
            when 'alt+left', 'alt+right', 'alt+shift+left', 'alt+shift+right'
                return @moveCursorsToWordBoundary key, event.shiftKey

            when 'command+shift+up', 'command+shift+down'          then return @delCursors   key
            when 'ctrl+up', 'ctrl+down', 'ctrl+left', 'ctrl+right' then return @alignCursors key

        return if mod and not key?.length
        
        switch key
            
            when 'esc'     then return @cancelCursorsAndHighlights()
            when 'home'    then return @singleCursorAtPos [0, 0],              event.shiftKey
            when 'end'     then return @singleCursorAtPos [0,@lines.length-1], event.shiftKey
            when 'page up'      
                @moveCursorsUp event.shiftKey, @numFullLines()-3
                event.preventDefault() # prevent view from scrolling
                return
            when 'page down'    
                @moveCursorsDown event.shiftKey, @numFullLines()-3
                event.preventDefault() # prevent view from scrolling
                return
            
            when 'down', 'right', 'up', 'left' 
                @moveCursors key, event.shiftKey
                event.preventDefault() # prevent view from scrolling
                                                                                    
        ansiKeycode = require 'ansi-keycode'
        if ansiKeycode(event)?.length == 1 and mod in ["shift", ""]
            @insertUserCharacter ansiKeycode event

module.exports = ViewBase
