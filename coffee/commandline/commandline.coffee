
#  0000000   0000000   00     00  00     00   0000000   000   000  0000000    000      000  000   000  00000000
# 000       000   000  000   000  000   000  000   000  0000  000  000   000  000      000  0000  000  000     
# 000       000   000  000000000  000000000  000000000  000 0 000  000   000  000      000  000 0 000  0000000 
# 000       000   000  000 0 000  000 0 000  000   000  000  0000  000   000  000      000  000  0000  000     
#  0000000   0000000   000   000  000   000  000   000  000   000  0000000    0000000  000  000   000  00000000
{
fileList,
$}        = require '../tools/tools'
ViewBase  = require '../editor/viewbase'
log       = require '../tools/log'
path      = require 'path'

class Commandline extends ViewBase
    
    constructor: (viewElem) ->
            
        @fontSizeDefault = 24

        super viewElem
        
        @hideNumbers()
        @size.lineHeight = @scroll.viewHeight
        @scroll?.setLineHeight @size.lineHeight
        @setText ""
                
        @cmmd = $('.commandline-command')
        
        @commands = {}
        @command = null

        @loadCommands()

    setName: (name) -> @cmmd.innerHTML = name
                
    setLines: (l) ->
        @scroll.reset()
        super l
    
    setAndSelectText: (t) ->
        @setLines [t]
        @selectAll()

    changed: (changeInfo) ->
        super changeInfo
        if changeInfo.changed.length
            @command?.changed @lines[0]
        
    loadCommands: ->
        files = fileList "#{__dirname}/../commands"
        for file in files
            commandClass = require file
            command = new commandClass @
            command.setPrefsID commandClass.name.toLowerCase()
            @commands[command.prefsID] = command
          
    #  0000000  000000000   0000000   00000000   000000000
    # 000          000     000   000  000   000     000   
    # 0000000      000     000000000  0000000       000   
    #      000     000     000   000  000   000     000   
    # 0000000      000     000   000  000   000     000   
    
    startCommand: (name, combo) ->
        @command?.cancel()
        window.split.showCommandline()
        @view.focus()
        @setName name
        @command = @commands[name]
        @results @command.start combo # <-- command start
        # @setAndSelectText 
                
    # 00000000  000   000  00000000   0000000  000   000  000000000  00000000
    # 000        000 000   000       000       000   000     000     000     
    # 0000000     00000    0000000   000       000   000     000     0000000 
    # 000        000 000   000       000       000   000     000     000     
    # 00000000  000   000  00000000   0000000   0000000      000     00000000
    
    execute: ->
        @results @command?.execute @lines[0]
        
    results: (r) ->
        @setText r.text if r?.text?
        @setName r.name if r?.name?
        if r?.select then @selectAll()
        else @selectNone() 
        window.split.focusEditor() if r?.focus == 'editor'
        
    cancel: ->
        @command?.cancel()
        window.split.focusOnEditorOrHistory()
                                
    # 000   000  00000000  000   000
    # 000  000   000        000 000 
    # 0000000    0000000     00000  
    # 000  000   000          000   
    # 000   000  00000000     000   

    globalModKeyComboEvent: (mod, key, combo, event) ->
        for n,c of @commands            
            if combo == 'esc' then return @cancel()
            for sc in c.shortcuts
                if sc == combo then return @startCommand n, combo                
        return 'unhandled'            

    handleModKeyComboEvent: (mod, key, combo, event) ->

        switch combo
            when 'enter'            then return @execute()
            when 'up'               then return @setAndSelectText @command?.prev()
            when 'down'             then return @setAndSelectText @command?.next()
            when 'esc'              then return @cancel()
            when 'command+k'        then return @selectAll() + @deleteSelection()
            when 'tab', 'shift+tab' then return
        
        return 'unhandled'
    
module.exports = Commandline