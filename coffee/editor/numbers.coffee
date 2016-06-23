# 000   000  000   000  00     00  0000000    00000000  00000000    0000000
# 0000  000  000   000  000   000  000   000  000       000   000  000     
# 000 0 000  000   000  000000000  0000000    0000000   0000000    0000000 
# 000  0000  000   000  000 0 000  000   000  000       000   000       000
# 000   000   0000000   000   000  0000000    00000000  000   000  0000000 
{
setStyle,
first,
last,
$}  = require '../tools/tools'
log = require '../tools/log'
_   = require 'lodash'

class Numbers

    constructor: (@editor) ->
        
        @elem = $(".numbers", @editor.view)
        @editor.on 'clearLines',       @onClearLines
        @editor.on 'lineInserted',     @onLineInserted
        @editor.on 'lineDeleted',      @onLineDeleted
        @editor.on 'lineExposed',      @onLineExposed
        @editor.on 'lineVanished',     @onLineVanished
        @editor.on 'lineExposedTop',   @onLineExposedTop
        @editor.on 'lineVanishedTop',  @onLineVanishedTop
        @editor.on 'exposeTopChanged', @renumber
        @editor.on 'fontSizeChanged',  @onFontSizeChange
        @editor.on 'highlight',        @onSelectionOrCursors
        @editor.on 'selection',        @onSelectionOrCursors
        @editor.on 'cursors',          @onSelectionOrCursors
        @onFontSizeChange()
    
    #  0000000  00000000  000      00000000   0000000  000000000  000   0000000   000   000
    # 000       000       000      000       000          000     000  000   000  0000  000
    # 0000000   0000000   000      0000000   000          000     000  000   000  000 0 000
    #      000  000       000      000       000          000     000  000   000  000  0000
    # 0000000   00000000  0000000  00000000   0000000     000     000   0000000   000   000
       
    onSelectionOrCursors: =>
        top = @editor.scroll.exposeTop
        bot = @editor.scroll.exposeBot
        sr = @editor.rangesFromTopToBotInRanges top, bot, @editor.selections
        hr = @editor.rangesFromTopToBotInRanges top, bot, @editor.highlights        
        cr = @editor.rangesFromTopToBotInRanges top, bot, @editor.rangesForCursors()
        hi = @editor.sortedLineIndicesInRanges hr
        si = @editor.sortedLineIndicesInRanges sr
        ci = @editor.sortedLineIndicesInRanges cr
        li = top
        for child in @elem.children
            cls = ''
            if li in ci
                cls += ' cursored'
            if li in si
                cls += ' selected'
            if li in hi
                cls += ' highligd'
            li += 1
            child.className = 'linenumber ' + cls
       
    # 00000000   0000000   000   000  000000000   0000000  000  0000000  00000000
    # 000       000   000  0000  000     000     000       000     000   000     
    # 000000    000   000  000 0 000     000     0000000   000    000    0000000 
    # 000       000   000  000  0000     000          000  000   000     000     
    # 000        0000000   000   000     000     0000000   000  0000000  00000000
        
    onFontSizeChange: => 
        @elem.style.lineHeight = "#{@editor.size.lineHeight}px"        
        if @editor.size.fontSize < 13
            # log "@editor.size.fontSize", @editor.size.fontSize
            @elem.style.fontSize = "#{@editor.size.fontSize}px"
    
    # 00000000  000   000  00000000    0000000    0000000  00000000
    # 000        000 000   000   000  000   000  000       000     
    # 0000000     00000    00000000   000   000  0000000   0000000 
    # 000        000 000   000        000   000       000  000     
    # 00000000  000   000  000         0000000   0000000   00000000
        
    onLineExposed: (e) =>
        # console.log "numbers.onLineExposed #{@editor.name} #{e.lineIndex}" if @editor.name == 'logview'
        @elem.appendChild @addLine e.lineIndex
        
    onLineExposedTop: (e) =>
        # console.log "numbers.onLineExposedTop #{@editor.name} #{e.lineIndex}" if @editor.name == 'logview'
        @elem.insertBefore @addLine(e.lineIndex), @elem.firstChild
        
    # 000  000   000   0000000  00000000  00000000   000000000  00000000  0000000  
    # 000  0000  000  000       000       000   000     000     000       000   000
    # 000  000 0 000  0000000   0000000   0000000       000     0000000   000   000
    # 000  000  0000       000  000       000   000     000     000       000   000
    # 000  000   000  0000000   00000000  000   000     000     00000000  0000000  
        
    onLineInserted: (li) =>
        top = @editor.scroll.exposeTop
        bot = @editor.scroll.exposeBot                
        @elem.appendChild @addLine @editor.scroll.exposeBot+1
        
    # 0000000    00000000  000      00000000  000000000  00000000  0000000  
    # 000   000  000       000      000          000     000       000   000
    # 000   000  0000000   000      0000000      000     0000000   000   000
    # 000   000  000       000      000          000     000       000   000
    # 0000000    00000000  0000000  00000000     000     00000000  0000000  
        
    onLineDeleted: (li) =>
        top = @editor.scroll.exposeTop
        bot = @editor.scroll.exposeBot
        if top <= li <= bot
            @elem.lastChild.remove()
    
    # 000   000   0000000   000   000  000   0000000  000   000
    # 000   000  000   000  0000  000  000  000       000   000
    #  000 000   000000000  000 0 000  000  0000000   000000000
    #    000     000   000  000  0000  000       000  000   000
    #     0      000   000  000   000  000  0000000   000   000
    
    onLineVanished:    (e) => @elem.lastChild?.remove()
    onLineVanishedTop: (e) => @elem.firstChild?.remove()
    onClearLines:          => @elem.innerHTML = ""
    
    #  0000000   0000000    0000000    000      000  000   000  00000000
    # 000   000  000   000  000   000  000      000  0000  000  000     
    # 000000000  000   000  000   000  000      000  000 0 000  0000000 
    # 000   000  000   000  000   000  000      000  000  0000  000     
    # 000   000  0000000    0000000    0000000  000  000   000  00000000
    
    addLine: (li) ->
        # console.log "numbers.addLine #{@editor.name} #{li}" if @editor.name == 'logview'
        div = document.createElement "div"
        div.className = "linenumber"
        pre = document.createElement "span"
        pre.innerHTML = "#{li}"
        div.appendChild pre
        div
        
    # 00000000   00000000  000   000  000   000  00     00  0000000    00000000  00000000 
    # 000   000  000       0000  000  000   000  000   000  000   000  000       000   000
    # 0000000    0000000   000 0 000  000   000  000000000  0000000    0000000   0000000  
    # 000   000  000       000  0000  000   000  000 0 000  000   000  000       000   000
    # 000   000  00000000  000   000   0000000   000   000  0000000    00000000  000   000
        
    renumber: (e) =>
        console.log "numbers.renumber #{@editor.name} from #{e.new} to #{e.new+@elem.children.length-1}" if @editor.name == 'logview'
        li = e.new
        for e in @elem.children
            e.firstChild.innerHTML = "#{li}"
            li += 1

module.exports = Numbers
