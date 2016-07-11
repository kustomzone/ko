# 00     00  00000000  000000000   0000000 
# 000   000  000          000     000   000
# 000000000  0000000      000     000000000
# 000 0 000  000          000     000   000
# 000   000  00000000     000     000   000
{
setStyle,
first,
last,
$}  = require '../tools/tools'
log = require '../tools/log'
str = require '../tools/str'
_   = require 'lodash'
fs  = require 'fs'

class Meta 
    
    constructor: (@editor) ->
        
        @metas = [] # [lineIndex, [start, end], {href: ...}]
        @elem = $(".meta", @editor.view)
        @editor.on 'changed',          @onChanged
        @editor.on 'lineAppended',     @onLineAppended
        @editor.on 'clearLines',       @onClearLines
        @editor.on 'lineInserted',     @onLineInserted
        @editor.on 'willDeleteLine',   @onWillDeleteLine
        @editor.on 'lineExposed',      @onLineExposed
        @editor.on 'lineVanished',     @onLineVanished
        @editor.on 'lineExposedTop',   @onLineExposedTop
        @editor.on 'lineVanishedTop',  @onLineVanishedTop
        @editor.on 'exposeTopChanged', @onExposeTopChanged
        @editor.on 'fontSizeChanged',  @onFontSizeChange
        
        @editor.numbers.on 'numberAdded',   @onNumber
        @editor.numbers.on 'numberChanged', @onNumber

    #  0000000  000   000   0000000   000   000   0000000   00000000  0000000  
    # 000       000   000  000   000  0000  000  000        000       000   000
    # 000       000000000  000000000  000 0 000  000  0000  0000000   000   000
    # 000       000   000  000   000  000  0000  000   000  000       000   000
    #  0000000  000   000  000   000  000   000   0000000   00000000  0000000  
    
    onChanged: (changeInfo, action) =>
        return if not changeInfo.changed.length
        for li in changeInfo.changed
            for meta in @metasAtLineIndex li
                if meta[2].clss == "searchResult"
                    [file, line] = meta[2].href.split(':')
                    line -= 1
                    change = (a for a in action.lines when a.index == li)[0]
                    lineChange = 
                        before: change.before
                        after: change.after
                        index: line
                    @editor.emit 'fileLineChange', file, lineChange
                    meta[2].state = 'unsaved'
                    if meta[2].span?
                        button = @saveButton li
                        if not meta[2].span.innerHTML.startsWith "<span"
                            meta[2].span.innerHTML = button
                    else 
                        log "no span?"
         
    #  0000000   0000000   000   000  00000000
    # 000       000   000  000   000  000     
    # 0000000   000000000   000 000   0000000 
    #      000  000   000     000     000     
    # 0000000   000   000      0      00000000
         
    saveFileLineMetas: (file, lineMetas) ->
        fs.readFile file, encoding: 'UTF8', (err, data) =>
            return if err
            lines = data.split /\r?\n/
            for l in lineMetas
                lines[l[0]] = l[1]
            data = lines.join '\n'
            fs.writeFile file, data, encoding: 'UTF8', (err) =>
                return if err
                for l in lineMetas
                    meta = l[2]
                    delete meta[2].state
                    meta[2].span.innerHTML = meta[2].href.split(':')[1]
                    
    saveLine: (li) -> 
        for meta in @metasAtLineIndex li
            if meta[2].state == 'unsaved'
                [file, line] = meta[2].href.split(':')
                @saveFileLineMetas file, [[line-1, @editor.lines[meta[0]], meta]]

    saveChanges: ->
        fileLineMetas = {}
        for meta in @metas
            if meta[2].state == 'unsaved'
                [file, line] = meta[2].href.split(':')
                fileLineMetas[file] = [] if not fileLineMetas[file]?
                fileLineMetas[file].push [meta[0], @editor.lines[meta[0]], meta]

        for file, lineMetas of fileLineMetas
            @saveFileLineMetas file, lineMetas
        
        fileLineMetas.length
        
    saveButton: (li) ->
        "<span class=\"saveButton\" onclick=\"window.terminal.meta.saveLine(#{li});\">&#128190;</span>"
                    
    # 000   000  000   000  00     00  0000000    00000000  00000000 
    # 0000  000  000   000  000   000  000   000  000       000   000
    # 000 0 000  000   000  000000000  0000000    0000000   0000000  
    # 000  0000  000   000  000 0 000  000   000  000       000   000
    # 000   000   0000000   000   000  0000000    00000000  000   000
    
    onNumber: (e) =>
        metas = @metasAtLineIndex e.lineIndex
        for meta in metas
            meta[2].span = e.numberSpan
            switch meta[2].clss
                when 'searchResult'
                    e.numberSpan.innerHTML = meta[2].state == 'unsaved' and @saveButton(meta[0]) or meta[2].href.split(':')[1]
                else
                    e.numberSpan.innerHTML = '&nbsp;'

    # 0000000    000  000   000
    # 000   000  000  000   000
    # 000   000  000   000 000 
    # 000   000  000     000   
    # 0000000    000      0    

    addDiv: (meta) ->
        size = @editor.size
        sw = size.charWidth * (meta[1][1]-meta[1][0])
        tx = size.charWidth *  meta[1][0] + size.offsetX
        ty = size.lineHeight * (meta[0] - @editor.scroll.exposeTop)
        lh = size.lineHeight
        
        div = document.createElement 'div'
        div.className = "meta #{meta[2].clss ? ''}"
        div.style.transform = "translate(#{tx}px,#{ty}px)"
        div.style.width = "#{sw}px"
        div.style.height = "#{lh}px"
        if meta[2].href?
            div.setAttribute 'onclick', "window.loadFile('#{meta[2].href}');" 
            div.classList.add 'href'
        @elem.appendChild div
        if meta[2].div? # todo remove
            log "meta.addDiv wtf? li #{meta[0]}"
            alert "remove me!"
            meta[2].div.remove()
        meta[2].div = div
        
    #  0000000   00000000   00000000   00000000  000   000  0000000  
    # 000   000  000   000  000   000  000       0000  000  000   000
    # 000000000  00000000   00000000   0000000   000 0 000  000   000
    # 000   000  000        000        000       000  0000  000   000
    # 000   000  000        000        00000000  000   000  0000000  
    
    append: (meta) -> @metas.push [@editor.lines.length, [0, 0], meta]
    
    #  0000000   00000000   00000000   00000000  000   000  0000000    00000000  0000000  
    # 000   000  000   000  000   000  000       0000  000  000   000  000       000   000
    # 000000000  00000000   00000000   0000000   000 0 000  000   000  0000000   000   000
    # 000   000  000        000        000       000  0000  000   000  000       000   000
    # 000   000  000        000        00000000  000   000  0000000    00000000  0000000  
        
    onLineAppended: (e) =>        
        for meta in @metasAtLineIndex e.lineIndex
            meta[1][1] = e.text.length if meta[1][1] is 0
                
    metasAtLineIndex: (li) -> @editor.rangesForLineIndexInRanges li, @metas
    hrefAtLineIndex:  (li) -> 
        for meta in @metasAtLineIndex li
            return meta[2].href if meta[2].href?

    # 00000000   0000000   000   000  000000000   0000000  000  0000000  00000000
    # 000       000   000  0000  000     000     000       000     000   000     
    # 000000    000   000  000 0 000     000     0000000   000    000    0000000 
    # 000       000   000  000  0000     000          000  000   000     000     
    # 000        0000000   000   000     000     0000000   000  0000000  00000000
        
    onFontSizeChange: => log "meta.onFontSizeChange"

    # 00000000  000   000  00000000    0000000    0000000  00000000
    # 000        000 000   000   000  000   000  000       000     
    # 0000000     00000    00000000   000   000  0000000   0000000 
    # 000        000 000   000        000   000       000  000     
    # 00000000  000   000  000         0000000   0000000   00000000
        
    onLineExposed: (e) =>
        for meta in @metasAtLineIndex e.lineIndex
            @addDiv meta
        
    onLineExposedTop: (e) => @onLineExposed e
    
    onExposeTopChanged: (e) => @updatePositionsBelowLineIndex e.new
        
    updatePositionsBelowLineIndex: (li) ->      
        size = @editor.size
        for meta in @editor.rangesFromTopToBotInRanges li, @editor.scroll.exposeBot, @metas
            tx = size.charWidth *  meta[1][0] + size.offsetX
            ty = size.lineHeight * (meta[0] - @editor.scroll.exposeTop)
            meta[2].div?.style.transform = "translate(#{tx}px,#{ty}px)"        
        
    # 000  000   000   0000000  00000000  00000000   000000000  00000000  0000000  
    # 000  0000  000  000       000       000   000     000     000       000   000
    # 000  000 0 000  0000000   0000000   0000000       000     0000000   000   000
    # 000  000  0000       000  000       000   000     000     000       000   000
    # 000  000   000  0000000   00000000  000   000     000     00000000  0000000  
        
    onLineInserted: (li) => 
        for meta in @editor.rangesFromTopToBotInRanges li+1, @editor.lines.length, @metas
            meta[0] += 1
        @updatePositionsBelowLineIndex li
        
    # 0000000    00000000  000      00000000  000000000  00000000  0000000  
    # 000   000  000       000      000          000     000       000   000
    # 000   000  0000000   000      0000000      000     0000000   000   000
    # 000   000  000       000      000          000     000       000   000
    # 0000000    00000000  0000000  00000000     000     00000000  0000000  
    
    onWillDeleteLine: (li) => 
        @onLineVanished lineIndex: li
        _.pullAll @metas, @metasAtLineIndex li
        for meta in @editor.rangesFromTopToBotInRanges li+1, @editor.lines.length, @metas
            meta[0] -= 1
        @updatePositionsBelowLineIndex li
    
    # 000   000   0000000   000   000  000   0000000  000   000
    # 000   000  000   000  0000  000  000  000       000   000
    #  000 000   000000000  000 0 000  000  0000000   000000000
    #    000     000   000  000  0000  000       000  000   000
    #     0      000   000  000   000  000  0000000   000   000

    onLineVanishedTop: (e) => 
        @onLineVanished e
        @updatePositionsBelowLineIndex e.lineIndex
        
    onLineVanished:    (e) => 
        for meta in @metasAtLineIndex e.lineIndex
            meta[2].div?.remove()
            meta[2].div = null        
    
    #  0000000  000      00000000   0000000   00000000 
    # 000       000      000       000   000  000   000
    # 000       000      0000000   000000000  0000000  
    # 000       000      000       000   000  000   000
    #  0000000  0000000  00000000  000   000  000   000
          
    clear: => 
        @elem.innerHTML = ""
        @metas = []
        
    onClearLines: => 
        @elem.innerHTML = ""
        for meta in @metas
            meta[2].div = null
    
module.exports = Meta