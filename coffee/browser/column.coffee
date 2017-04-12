#  0000000   0000000   000      000   000  00     00  000   000
# 000       000   000  000      000   000  000   000  0000  000
# 000       000   000  000      000   000  000000000  000 0 000
# 000       000   000  000      000   000  000 0 000  000  0000
#  0000000   0000000   0000000   0000000   000   000  000   000

{ relative, keyinfo, path, post, elem, clamp, error, log, $, _ 
}   = require 'kxk'
Row = require './row'

class Column
    
    constructor: (@browser) ->
        
        @index = @browser.columns.length
        # log "Column #{@index}"

        @rows = []
        @div = elem class: 'browserColumn', tabIndex: @index, id: "column#{@index}"
        @browser.cols.appendChild @div
        
        @div.addEventListener 'focus',   @onFocus
        @div.addEventListener 'blur',    @onBlur
        @div.addEventListener 'keydown', @onKey
        
    #  0000000  00000000  000000000  000  000000000  00000000  00     00   0000000  
    # 000       000          000     000     000     000       000   000  000       
    # 0000000   0000000      000     000     000     0000000   000000000  0000000   
    #      000  000          000     000     000     000       000 0 000       000  
    # 0000000   00000000     000     000     000     00000000  000   000  0000000   
    
    setItems: (@items, @parent) ->
        # log @items, @parent
        @clear()
        for item in @items
            @rows.push new Row @, item
        @
        
    isEmpty: -> _.isEmpty @rows
    clear:   -> 
        @div.innerHTML = ''
        @rows = []
        
    #  0000000    0000000  000000000  000  000   000  00000000  
    # 000   000  000          000     000  000   000  000       
    # 000000000  000          000     000   000 000   0000000   
    # 000   000  000          000     000     000     000       
    # 000   000   0000000     000     000      0      00000000  
   
    navigateTo: (opt) ->
        target = _.isString(opt) and opt or opt?.file
        log 'navigateTo target:', target, 'parent:', @parent.abs
        log 'relative', relpath = relative target, @parent.abs
        log 'first', relitem = _.first relpath.split path.sep

    setActiveRow: (row) ->
        row = @rows[row] if _.isNumber row
        log 'row.setActive?', row.setActive?
        row?.setActive?()
       
    activeRow: -> 
        for r in @rows
            return r if r.isActive()
        
    # 000   000   0000000   000   000  000   0000000    0000000   000000000  00000000  
    # 0000  000  000   000  000   000  000  000        000   000     000     000       
    # 000 0 000  000000000   000 000   000  000  0000  000000000     000     0000000   
    # 000  0000  000   000     000     000  000   000  000   000     000     000       
    # 000   000  000   000      0      000   0000000   000   000     000     00000000  

    navigateRows: (key) ->
        # log 'key', key, @numRows()
        return error "no rows in column #{@index}?" if not @numRows()
        index = @activeRow()?.index() ? -1
        error "no index from activeRow? #{index}?", @activeRow() if not index? or Number.isNaN index
        index = switch key
            when 'up'        then index-1 #(@numRows() + index-1) % @numRows() 
            when 'down'      then index+1
            when 'home'      then 0
            when 'end'       then @numRows()-1
            when 'page up'   then index-@numVisible()
            when 'page down' then index+@numVisible()
            else index
        error "no index #{index}? #{@numVisible()}" if not index? or Number.isNaN index        
        # log 'clamp index', index, @numRows()
        index = clamp 0, @numRows()-1, index
        error "no row at index #{index}/#{@numRows()-1}?", @numRows() if not @rows[index]?.activate?
        @rows[index].activate()
    
    navigateCols: (key) ->
        item = @activeRow()?.item
        type = item.type
        switch key
            when 'left'  then @browser.navigate 'left'
            when 'right' then @browser.navigate 'right'
            when 'enter'
                if type == 'dir'
                    @browser.browse item.abs
                else
                    post.emit 'focus', 'editor'

    numRows: -> @rows.length ? 0         
    numVisible: -> 20 # TODO
    
    # 00000000   0000000    0000000  000   000   0000000  
    # 000       000   000  000       000   000  000       
    # 000000    000   000  000       000   000  0000000   
    # 000       000   000  000       000   000       000  
    # 000        0000000    0000000   0000000   0000000   
    
    hasFocus: -> @div.classList.contains 'focus'

    focus: ->
        if not @activeRow() and @numRows()
            @rows[0].setActive()
        @div.focus()
        @
        
    onFocus: => @div.classList.add 'focus'
    onBlur:  => @div.classList.remove 'focus'
        
    # 000   000  00000000  000   000  
    # 000  000   000        000 000   
    # 0000000    0000000     00000    
    # 000  000   000          000     
    # 000   000  00000000     000     
    
    onKey: (event) =>
        {mod,key,combo} = keyinfo.forEvent event
        # log "#{@index} #{combo}"
        switch combo
            when 'up', 'down', 'page up', 'page down', 'home', 'end' then @navigateRows key
            when 'right', 'left', 'enter' then @navigateCols key
        
module.exports = Column
