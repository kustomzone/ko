#  0000000  00000000   000      000  000000000
# 000       000   000  000      000     000   
# 0000000   00000000   000      000     000   
#      000  000        000      000     000   
# 0000000   000        0000000  000     000   
{
clamp,
sh,sw,
last,
$}    = require './tools/tools'
log   = require './tools/log'
pos   = require './tools/pos'
drag  = require './tools/drag'
prefs = require './tools/prefs'
event = require 'events'

class Split extends event
    
    # 000  000   000  000  000000000
    # 000  0000  000  000     000   
    # 000  000 0 000  000     000   
    # 000  000  0000  000     000   
    # 000  000   000  000     000   
    
    constructor: () ->

        @commandlineHeight = 30
        @handleHeight      = 6
        @logVisible        = undefined
        
        @elem        = $('.split')
        @titlebar    = $('.titlebar')
        @topHandle   = $('.handle.top')
        @editHandle  = $('.handle.edit')
        @logHandle   = $('.handle.log')
        @terminal    = $('.terminal')
        @commandline = $('.commandline')
        @editor      = $('.editor')
        @logview     = $('.logview')

        @splitPos    = [-@handleHeight,0,@elemHeight()]

        @handles     = [@topHandle, @editHandle, @logHandle]
        @panes       = [@terminal, @commandline, @editor, @logview]
                            
        @dragTop = new drag
            target: @topHandle
            cursor: 'ns-resize'
            onStop: (drag) => @snap()
            onMove: (drag) => @splitAt 0, drag.pos.y - @elemTop() - @handleHeight/2
        
        @dragBot = new drag
            target: @editHandle
            cursor: 'ns-resize'
            onStop: (drag) => @snap()
            onMove: (drag) => @splitAt 1, drag.pos.y - @elemTop() - @handleHeight/2
            
        @dragLog = new drag
            target: @logHandle
            cursor: 'ns-resize'
            onStop: (drag) => @snap()
            onMove: (drag) => 
                if @splitPosY(2)-@splitPosY(1) < 10
                    @splitAt 1, drag.pos.y - @elemTop() - @handleHeight/2
                    @splitAt 2, drag.pos.y - @elemTop() - @handleHeight/2
                else
                    @splitAt 2, drag.pos.y - @elemTop() - @handleHeight/2

    setWinID: (@winID) ->
        s = @getState 'split', [-@handleHeight,0,@elemHeight()]        
        @logVisible = s[2] < @elemHeight()
        display = @logVisible and 'inherit' or 'none'
        @logview.style.display = display
        @logHandle.style.display = display        
        @applySplit s

    #  0000000  00000000   000      000  000000000
    # 000       000   000  000      000     000   
    # 0000000   00000000   000      000     000   
    #      000  000        000      000     000   
    # 0000000   000        0000000  000     000   
    
    splitAt: (i, y) -> 
        s = []
        for h in [0...@handles.length]
            if h == i
                s.push y
            else
                s.push @splitPosY h
        
        if i == 0
            s[1] = s[0] + @commandlineHeight + @handleHeight
        if i == 1
            s[0] = s[1] - @commandlineHeight - @handleHeight
                
        @applySplit s
    
    #  0000000   00000000   00000000   000      000   000
    # 000   000  000   000  000   000  000       000 000 
    # 000000000  00000000   00000000   000        00000  
    # 000   000  000        000        000         000   
    # 000   000  000        000        0000000     000   
        
    applySplit: (s) ->
        for i in [0...s.length]
            s[i] = clamp (i and s[i-1] or -@handleHeight), @elemHeight(), s[i]
        @handles[0].style.height = "#{clamp 0, @handleHeight, @handleHeight+s[0]}px"
            
        if not @logVisible
            s[2] = @elemHeight()
            
        @splitPos = _.clone s
        
        for h in [0...@panes.length]
            newHeight = Math.max 0, switch
                when h is 0 then s[0]
                when h is s.length then @logVisible and @elemHeight()-last(s)-@handleHeight or 0
                else s[h]-s[h-1]-@handleHeight
                    
            @panes[h].style.height = "#{newHeight}px"
            if h == 3
                if newHeight > 0
                    @setState 'logHeight', newHeight
                else
                    @setLogVisible false if @logVisible
        @elem.scrollTop = 0
        @setState 'split', s
        @emit     'split', s
        
    # 00000000   00000000   0000000  000  0000000  00000000  0000000  
    # 000   000  000       000       000     000   000       000   000
    # 0000000    0000000   0000000   000    000    0000000   000   000
    # 000   000  000            000  000   000     000       000   000
    # 000   000  00000000  0000000   000  0000000  00000000  0000000  
    
    resized: =>
        height = sh()-@titlebar.getBoundingClientRect().height
        width  = sw()
        @elem.style.height = "#{height}px"
        @elem.style.width  = "#{width}px"
        s = []
        e = @editorHeight()
        for h in [0...@handles.length]
            s.push clamp -@handleHeight, @elemHeight(), @splitPosY h
        if e == 0 and not @logVisible # keep editor closed
            s[1] = s[2] = @elemHeight()  
            s[0] = s[1] - @commandlineHeight - @handleHeight
        @applySplit s
    
    # 00000000    0000000    0000000          0000000  000  0000000  00000000
    # 000   000  000   000  000         0    000       000     000   000     
    # 00000000   000   000  0000000   00000  0000000   000    000    0000000 
    # 000        000   000       000    0         000  000   000     000     
    # 000         0000000   0000000          0000000   000  0000000  00000000
    
    elemTop:    -> @elem.getBoundingClientRect().top
    elemHeight: -> @elem.getBoundingClientRect().height - @handleHeight
    splitPosY:  (i) -> 
        if i < @splitPos.length
            @splitPos[i]
        else
            @elemHeight()
            
    paneHeight: (i) -> @panes[i].getBoundingClientRect().height
        
    terminalHeight:    -> @paneHeight 0
    editorHeight:      -> @paneHeight 2
    logviewHeight:     -> @paneHeight 3
    
    terminalVisible:    -> @terminalHeight() > 0
    hideTerminal:       -> @splitAt 0, 0
    editorVisible:      -> @editorHeight() > 0
    hideEditor:         -> @splitAt 1, @elemHeight()
    commandlineVisible: -> @splitPosY(1) > 0

    # 0000000     0000000 
    # 000   000  000   000
    # 000   000  000   000
    # 000   000  000   000
    # 0000000     0000000 
    
    do: (sentence) ->
        words = sentence.split ' '
        action = words[0]
        what = words[1]
        if what? and action in ['maximize', 'enlarge']
            switch action
                when 'maximize' then delta = @elemHeight()
                when 'enlarge'
                    if words[2] == 'by'
                        delta = parseInt words[3]
                    else
                        fh = @terminalHeight() + @commandlineHeight + @editorHeight()
                        delta = parseInt 0.25 * fh
            switch what
                when 'editor'   then return @moveCommandLineBy -delta
                when 'terminal' then return @moveCommandLineBy  delta        
            
        log "split.do warning! unhandled do command? #{sentence}?"
        
    # 00     00   0000000   000   000  00000000   0000000  00     00  0000000  
    # 000   000  000   000  000   000  000       000       000   000  000   000
    # 000000000  000   000   000 000   0000000   000       000000000  000   000
    # 000 0 000  000   000     000     000       000       000 0 000  000   000
    # 000   000   0000000       0      00000000   0000000  000   000  0000000  
    
    moveCommandLineBy: (delta) ->
        @splitAt 0, clamp 0, @elemHeight() - @commandlineHeight - @handleHeight, delta + @splitPosY 0       
        
    #  0000000   0000000   00     00  00     00   0000000   000   000  0000000    000      000  000   000  00000000
    # 000       000   000  000   000  000   000  000   000  0000  000  000   000  000      000  0000  000  000     
    # 000       000   000  000000000  000000000  000000000  000 0 000  000   000  000      000  000 0 000  0000000 
    # 000       000   000  000 0 000  000 0 000  000   000  000  0000  000   000  000      000  000  0000  000     
    #  0000000   0000000   000   000  000   000  000   000  000   000  0000000    0000000  000  000   000  00000000
    
    isCommandlineVisible: -> @splitPosY(1) > @commandlineHeight 
    
    hideCommandline: -> 
        @splitAt 1, 0
        @emit 'commandline', 'hidden'
        
    showCommandline: -> 
        if 0 >= @splitPosY 1
            @splitAt 0, 0
            @emit 'commandline', 'shown'
    
    show: (n) ->
        switch n
            when 'terminal' then @splitAt 0, 0.5*@splitPosY 2 if @paneHeight(0) < 100
            when 'editor'   then @splitAt 1, 0.5*@splitPosY 2 if @paneHeight(2) < 100
            when 'command'  then @splitAt 0, 0                if @paneHeight(1) < @commandlineHeight
            when 'logview'  then @showLog()
            else
                log "split.show warning! unhandled #{n}!"

    # 000       0000000    0000000 
    # 000      000   000  000      
    # 000      000   000  000  0000
    # 000      000   000  000   000
    # 0000000   0000000    0000000 
    
    showLog:   -> @setLogVisible true
    hideLog:   -> @setLogVisible false
    toggleLog: -> @setLogVisible not @logVisible
    setLogVisible: (v) ->
        if @logVisible != v
            @logVisible = v
            if v and @logviewHeight() <= 0
                @splitAt 2, @elemHeight() - Math.max(100, @getState('logHeight', 200))-@handleHeight
            else if @logviewHeight() > 0 and not v
                @splitAt 2, @elemHeight()
            display = v and 'inherit' or 'none'
            @logview.style.display   = display
            @logHandle.style.display = display            
            window.logview.resized()
            
    clearLog: -> window.logview.setText ""
    showOrClearLog: -> 
        if @logVisible
            @clearLog()
        else
            @showLog()
     
    #  0000000  000   000   0000000   00000000 
    # 000       0000  000  000   000  000   000
    # 0000000   000 0 000  000000000  00000000 
    #      000  000  0000  000   000  000      
    # 0000000   000   000  000   000  000      
    
    snap: ->
        y0 = @splitPosY 0
        y1 = @splitPosY 1
        y2 = @splitPosY 2
        if y0 < -@handleHeight
            @splitAt 0, -@handleHeight
        else if y1 < 0
            @splitAt 1, 0
        else if y1 > 0
            if y1 < (@commandlineHeight+@handleHeight)/2
                @splitAt 1, 0
            else if y1 <  (@commandlineHeight+@handleHeight)*2
                @splitAt 0, 0
            else if y1 > @splitPosY(2) - 40
                @splitAt 1, @splitPosY(2)
        else if y2 > @elemHeight()
            @splitAt 2, @elemHeight()

    # 00000000   0000000    0000000  000   000   0000000
    # 000       000   000  000       000   000  000     
    # 000000    000   000  000       000   000  0000000 
    # 000       000   000  000       000   000       000
    # 000        0000000    0000000   0000000   0000000 
    
    focus: (n) -> $(n)?.focus()
    reveal: (n) -> @show n
    focusAnything: ->
        return @focus '.editor' if @editorVisible()
        return @focus '.terminal' if @terminalVisible()
        @focus '.commandline-editor'
        
    #  0000000  000000000   0000000   000000000  00000000
    # 000          000     000   000     000     000     
    # 0000000      000     000000000     000     0000000 
    #      000     000     000   000     000     000     
    # 0000000      000     000   000     000     00000000
            
    setState: (key, value) ->
        if @winID
            prefs.set "windows:#{@winID}:#{key}", value
        
    getState: (key, value) ->
        if @winID
            prefs.get "windows:#{@winID}:#{key}", value
        else
            value

module.exports = Split
