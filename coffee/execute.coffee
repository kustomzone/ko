#00000000  000   000  00000000   0000000  000   000  000000000  00000000
#000        000 000   000       000       000   000     000     000     
#0000000     00000    0000000   000       000   000     000     0000000 
#000        000 000   000       000       000   000     000     000     
#00000000  000   000  00000000   0000000   0000000      000     00000000

log      = require './tools/log'
str      = require './tools/str'
_        = require 'lodash'
noon     = require 'noon'
colors   = require 'colors'
coffee   = require 'coffee-script'
electron = require 'electron'
pty      = require 'pty.js'

class Execute
        
    constructor: (cfg={}) -> 
        @childp  = null
        @main    = cfg?.main
        @winID   = cfg?.winID
        @cmdID   = cfg?.cmdID
        @command = cfg?.command
        @cwd     = cfg?.cwd ? process.cwd()
        @rest    = ''
        @shell() if cfg?.winID
        if @command?
            @term cfg
        else if @main?
            @initCoffee()
    
    #  0000000   0000000   00000000  00000000  00000000  00000000
    # 000       000   000  000       000       000       000     
    # 000       000   000  000000    000000    0000000   0000000 
    # 000       000   000  000       000       000       000     
    #  0000000   0000000   000       000       00000000  00000000
    
    initCoffee: =>
        try
            global.main = @main
            restoreCWD = process.cwd()
            process.chdir __dirname
            coffee.eval """                
                str    = require './tools/str' 
                _      = require 'lodash'
                coffee = require 'coffee-script'
                {clamp,last,first,fileExists,dirExists} = require './tools/tools'
                {max,min,abs,round,ceil,floor,sqrt,pow,exp,log10,sin,cos,tan,acos,asin,atan,PI,E} = Math
                (global[r] = require r for r in ['path', 'fs', 'noon', 'colors', 'electron'])                    
                ipc           = electron.ipcMain
                BrowserWindow = electron.BrowserWindow
                log = -> BrowserWindow.fromId(winID).webContents.send 'executeResult', [].slice.call(arguments, 0), cmdID
                """
            process.chdir restoreCWD
        catch e
            console.log 'wtf?'
            console.error colors.red.bold '[ERROR]', colors.red e
    
    execute: (code) =>
        try
            coffee.eval code
        catch e
            console.error colors.red.bold '[ERROR]', colors.red e
            error: e.toString()
            
    executeCoffee: (cfg) => 
        coffee.eval "winID = #{cfg.winID}"
        coffee.eval "cmdID = #{cfg.cmdID}"
        result = @execute cfg.command
        if not result?
            result = 'undefined'
        else if typeof(result) != 'object' or not result.error? and _.size(result) == 1
            result = str result
        @main.winWithID(cfg.winID).webContents.send 'executeResult', result, cfg.cmdID

    #  0000000  000   000  00000000  000      000    
    # 000       000   000  000       000      000    
    # 0000000   000000000  0000000   000      000    
    #      000  000   000  000       000      000    
    # 0000000   000   000  00000000  0000000  0000000
    
    shell: (command) =>
        @childp = pty.spawn '/usr/local/bin/bash', ['-i'], 
            name: 'xterm-color'
            cwd: @cwd
            env: process.env
        @childp.on 'data', @onShellData
      
    # 000000000  00000000  00000000   00     00
    #    000     000       000   000  000   000
    #    000     0000000   0000000    000000000
    #    000     000       000   000  000 0 000
    #    000     00000000  000   000  000   000
        
    term: (cfg) =>
        @rest    = ''
        @cmdID   = cfg?.cmdID
        @childp.write cfg.command + '\n'
        
    onShellData: (data) =>
        oRest = @rest
        @rest = ''
        if not data.endsWith '\n'
            lastIndex = data.lastIndexOf '\n'
            if lastIndex < 0
                @rest = oRest+data
                return
            @rest = data.slice lastIndex+1
            data = data.slice 0, lastIndex        
        else 
            data = data.slice 0,data.length-2
        data = oRest+data    
        electron.BrowserWindow.fromId(@winID).webContents.send 'shellCommandData', cmd: @cmdID, data: data

module.exports = Execute
