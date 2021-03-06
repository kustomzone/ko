# 00     00  000  000   000  000  00     00   0000000   00000000 
# 000   000  000  0000  000  000  000   000  000   000  000   000
# 000000000  000  000 0 000  000  000000000  000000000  00000000 
# 000 0 000  000  000  0000  000  000 0 000  000   000  000      
# 000   000  000  000   000  000  000   000  000   000  000      
{
getStyle,
clamp,
drag,
log,
str}    = require 'kxk'
profile = require '../tools/profile'
scroll  = require './scroll'

class Minimap

    constructor: (@editor) ->
        
        minimapWidth = parseInt getStyle '.minimap', 'width'
        @width = 2*minimapWidth
        @height = 8192
        @offsetLeft = 6
            
        @elem = document.createElement 'div'
        @elem.className = 'minimap'

        @topbot = document.createElement 'div'
        @topbot.className = "topbot"
        @elem.appendChild @topbot

        @selecti = document.createElement 'canvas'
        @selecti.className = "minimapSelections"
        @selecti.height    = @height
        @selecti.width     = @width
        @elem.appendChild @selecti

        @lines = document.createElement 'canvas'
        @lines.className = "minimapLines"
        @lines.height    = @height
        @lines.width     = @width
            
        @elem.addEventListener 'wheel', @editor.scrollbar?.onWheel
        @elem.appendChild @lines

        @highlig = document.createElement 'canvas'
        @highlig.className = "minimapHighlights"
        @highlig.height    = @height
        @highlig.width     = @width
        @elem.appendChild @highlig

        @cursors = document.createElement 'canvas'
        @cursors.className = "minimapCursors"
        @cursors.height    = @height
        @cursors.width     = @width
        @elem.appendChild @cursors

        @editor.view.appendChild    @elem
        @editor.on 'viewHeight',    @onEditorViewHeight
        @editor.on 'numLines',      @onEditorNumLines
        @editor.on 'changed',       @onChanged
        @editor.on 'highlight',     @drawHighlights
        @editor.scroll.on 'scroll', @onEditorScroll

        @scroll = new scroll 
            exposeMax:  @height/4
            lineHeight: 4
            viewHeight: 2*@editor.viewHeight()
            
        @drag = new drag 
            target:  @elem
            onStart: @onStart
            onMove:  @onDrag 
            cursor: 'pointer'
            
        @scroll.on 'clearLines',  @clearAll
        @scroll.on 'scroll',      @onScroll
        @scroll.on 'exposeLines', @onExposeLines
        @scroll.on 'vanishLines', @onVanishLines
        @scroll.on 'exposeLine',  @exposeLine

        @onScroll()  
        @drawLines()
        @drawTopBot()
            
    # 0000000    00000000    0000000   000   000
    # 000   000  000   000  000   000  000 0 000
    # 000   000  0000000    000000000  000000000
    # 000   000  000   000  000   000  000   000
    # 0000000    000   000  000   000  00     00

    drawSelections: =>
        @selecti.height = @height
        @selecti.width = @width
        ctx = @selecti.getContext '2d'

        ctx.fillStyle = '#444' 
        for r in rangesFromTopToBotInRanges @scroll.exposeTop, @scroll.exposeBot, @editor.selections()
            y = (r[0]-@scroll.exposeTop)*@scroll.lineHeight
            if 2*r[1][0] < @width
                offset = r[1][0] and @offsetLeft or 0
                ctx.fillRect offset+2*r[1][0], y, 2*(r[1][1]-r[1][0]), @scroll.lineHeight
                
    drawLines: (top=@scroll.exposeTop, bot=@scroll.exposeBot) =>
        ctx = @lines.getContext '2d'
        y = parseInt((top-@scroll.exposeTop)*@scroll.lineHeight)
        ctx.clearRect 0, y, @width, ((bot-@scroll.exposeTop)-(top-@scroll.exposeTop)+1)*@scroll.lineHeight        
        for li in [top..bot]
            diss = @editor.syntax.getDiss li
            y = parseInt((li-@scroll.exposeTop)*@scroll.lineHeight)
            if diss?.length
                for r in diss
                    break if 2*r.start >= @width
                    if r.clss?
                        ctx.fillStyle = @editor.syntax.colorForClassnames r.clss + " minimap"                    
                    else
                        ctx.fillStyle = @editor.syntax.colorForStyle r.styl
                    ctx.fillRect @offsetLeft+2*r.start, y, 2*r.match.length, @scroll.lineHeight

    drawHighlights: =>
        @highlig.height = @height
        @highlig.width = @width
        ctx = @highlig.getContext '2d'

        ctx.fillStyle = 'rgba(255,0,255,0.5)'
        for r in rangesFromTopToBotInRanges @scroll.exposeTop, @scroll.exposeBot, @editor.highlights()
            y = (r[0]-@scroll.exposeTop)*@scroll.lineHeight
            if 2*r[1][0] < @width                
                ctx.fillRect @offsetLeft+2*r[1][0], y, 2*(r[1][1]-r[1][0]), @scroll.lineHeight
            ctx.fillRect 0, y, @offsetLeft, @scroll.lineHeight

    drawCursors: =>
        @cursors.height = @height
        @cursors.width = @width
        ctx = @cursors.getContext '2d'
        
        for r in rangesFromTopToBotInRanges @scroll.exposeTop, @scroll.exposeBot, rangesFromPositions @editor.state.cursors()
            y = (r[0]-@scroll.exposeTop)*@scroll.lineHeight
            if 2*r[1][0] < @width
                ctx.fillStyle = '#f80'
                ctx.fillRect @offsetLeft+2*r[1][0], y, 2, @scroll.lineHeight
            ctx.fillStyle = 'rgba(255,128,0,0.5)'
            ctx.fillRect @offsetLeft-4, y, @offsetLeft-2, @scroll.lineHeight
                
        ctx.fillStyle = '#ff0'
        mc = @editor.mainCursor()
        y = (mc[1]-@scroll.exposeTop)*@scroll.lineHeight
        if 2*mc[0] < @width
            ctx.fillRect @offsetLeft+2*mc[0], y, 2, @scroll.lineHeight
        ctx.fillRect @offsetLeft-4, y, @offsetLeft-2, @scroll.lineHeight

    drawTopBot: =>
        lh = @scroll.lineHeight/2
        tb = (@editor.scroll.bot-@editor.scroll.top+1)*lh
        ty = 0
        if @editor.scroll.scrollMax
            ty = (Math.min(0.5*@scroll.viewHeight, @scroll.numLines*2)-tb) * @editor.scroll.scroll / @editor.scroll.scrollMax
        @topbot.style.height = "#{tb}px"
        @topbot.style.top    = "#{ty}px"
       
    # 00000000  000   000  00000000    0000000    0000000  00000000
    # 000        000 000   000   000  000   000  000       000     
    # 0000000     00000    00000000   000   000  0000000   0000000 
    # 000        000 000   000        000   000       000  000     
    # 00000000  000   000  000         0000000   0000000   00000000
    
    exposeLine: (li)   => @drawLines li, li
    onExposeLines: (e) => @drawLines @scroll.exposeTop, @scroll.exposeBot
    
    onVanishLines: (e) => 
        if e.top?
            @drawLines @scroll.exposeTop, @scroll.exposeBot
        else
            @clearRange @scroll.exposeBot, @scroll.exposeBot+@scroll.numLines
        
    #  0000000  000   000   0000000   000   000   0000000   00000000
    # 000       000   000  000   000  0000  000  000        000     
    # 000       000000000  000000000  000 0 000  000  0000  0000000 
    # 000       000   000  000   000  000  0000  000   000  000     
    #  0000000  000   000  000   000  000   000   0000000   00000000
    
    onChanged: (changeInfo) =>
        
        @drawSelections() if changeInfo.selects
        @drawCursors()    if changeInfo.cursors
        
        return if not changeInfo.changes.length
         
        @scroll.setNumLines @editor.numLines()
         
        for change in changeInfo.changes
            li = change.oldIndex
            break if not change.change in ['deleted', 'inserted']
            @drawLines li, li
             
        if li <= @scroll.exposeBot            
            @drawLines li, @scroll.exposeBot
        
    # 00     00   0000000   000   000   0000000  00000000
    # 000   000  000   000  000   000  000       000     
    # 000000000  000   000  000   000  0000000   0000000 
    # 000 0 000  000   000  000   000       000  000     
    # 000   000   0000000    0000000   0000000   00000000

    onDrag: (drag, event) =>   
        if @scroll.fullHeight > @scroll.viewHeight
            br = @elem.getBoundingClientRect()
            ry = event.clientY - br.top
            pc = 2*ry / @scroll.viewHeight
            li = parseInt pc * @editor.scroll.numLines
            @jumpToLine li, event
        else
            @jumpToLine @lineIndexForEvent(event), event

    onStart: (drag,event) => @jumpToLine @lineIndexForEvent(event), event
    
    jumpToLine: (li, event) ->        
        @editor.scrollTo (li-5) * @editor.scroll.lineHeight
        if not event.metaKey
            @editor.singleCursorAtPos [0, li+5], extend:event.shiftKey
        @editor.focus()
        @onEditorScroll()

    lineIndexForEvent: (event) ->
        st = @elem.scrollTop
        br = @elem.getBoundingClientRect()
        ly = clamp 0, @elem.offsetHeight, event.clientY - br.top
        py = parseInt(Math.floor(2*ly/@scroll.lineHeight)) + @scroll.top
        li = parseInt Math.min(@scroll.numLines-1, py)
        li

    #  0000000   000   000        00000000  0000000    000  000000000   0000000   00000000 
    # 000   000  0000  000        000       000   000  000     000     000   000  000   000
    # 000   000  000 0 000        0000000   000   000  000     000     000   000  0000000  
    # 000   000  000  0000        000       000   000  000     000     000   000  000   000
    #  0000000   000   000        00000000  0000000    000     000      0000000   000   000
    
    onEditorScroll: =>
        if @scroll.fullHeight > @scroll.viewHeight
            pc = @editor.scroll.scroll / @editor.scroll.scrollMax
            tp = parseInt pc * @scroll.scrollMax
            @scroll.to tp
        @drawTopBot()
    
    onEditorNumLines: (n) => 
        @onEditorViewHeight @editor.viewHeight() if n and @lines.height <= @scroll.lineHeight
        @scroll.setNumLines n
            
    onEditorViewHeight: (h) => 
        @scroll.setViewHeight 2*@editor.viewHeight()
        @onScroll()
        @onEditorScroll()

    #  0000000   0000000  00000000    0000000   000      000    
    # 000       000       000   000  000   000  000      000    
    # 0000000   000       0000000    000   000  000      000    
    #      000  000       000   000  000   000  000      000    
    # 0000000    0000000  000   000   0000000   0000000  0000000
            
    onScroll: =>
        y = parseInt -@height/4-@scroll.offsetTop/2
        x = parseInt @width/4
        t = "translate3d(#{x}px, #{y}px, 0px) scale3d(0.5, 0.5, 1)"
        @selecti.style.transform = t
        @highlig.style.transform = t
        @cursors.style.transform    = t
        @lines.style.transform      = t
        
    #  0000000  000      00000000   0000000   00000000 
    # 000       000      000       000   000  000   000
    # 000       000      0000000   000000000  0000000  
    # 000       000      000       000   000  000   000
    #  0000000  0000000  00000000  000   000  000   000
    
    clearRange: (top, bot) -> 
        ctx = @lines.getContext '2d'
        ctx.clearRect 0, (top-@scroll.exposeTop)*@scroll.lineHeight, 2*@width, (bot-top)*@scroll.lineHeight
        
    clearAll: =>
        @selecti.width = @selecti.width
        @highlig.width = @highlig.width
        @cursors.width = @cursors.width
        @topbot.width  = @topbot.width
        @lines.width   = @lines.width
        @drawTopBot()
        
module.exports = Minimap
