# 000  000   000  0000000    00000000  000   000  00000000  00000000 
# 000  0000  000  000   000  000        000 000   000       000   000
# 000  000 0 000  000   000  0000000     00000    0000000   0000000  
# 000  000  0000  000   000  000        000 000   000       000   000
# 000  000   000  0000000    00000000  000   000  00000000  000   000
{
fileExists,
resolve,
last
}        = require './tools/tools'
log      = require './tools/log'
_        = require 'lodash'
fs       = require 'fs'
path     = require 'path'
electron = require 'electron'
BrowserWindow = electron.BrowserWindow

class Indexer
    
    constructor: () ->
        
        @files   = Object.create null
        @classes = Object.create null
        @funcs   = Object.create null
        @words   = Object.create null
        @queue   = [] 
        
        @splitRegExp = new RegExp "[^\\w\\d#\\_]+", 'g'        
      
    # 000  000   000  0000000    00000000  000   000  00000000  000  000      00000000
    # 000  0000  000  000   000  000        000 000   000       000  000      000     
    # 000  000 0 000  000   000  0000000     00000    000000    000  000      0000000 
    # 000  000  0000  000   000  000        000 000   000       000  000      000     
    # 000  000   000  0000000    00000000  000   000  000       000  0000000  00000000
    
    indexFile: (file) ->
        
        return if @files[file]?
        
        fs.readFile file, 'utf8', (err, data) =>
            return if err?
            lines = data.split /\r?\n/
            fileInfo = 
                lines: lines.length
                funcs: []
            funcAdded = false
            funcStack = []
            currentClass = null
            for li in [0...lines.length]
                line = lines[li]
                
                if line.trim().length # ignoring empty lines
                    indent = line.search /\S/
                    
                    while funcStack.length and indent <= last(funcStack)[0]
                        last(funcStack)[1].last = li - 1
                        funcInfo = funcStack.pop()
                        fileInfo.funcs.push [funcInfo[1].line, funcInfo[1].last, funcInfo[2], funcInfo[1].class ? path.basename file, path.extname file]
            
                    if currentClass? and indent == 4                        
                        m = line.match /^\s+([\@]?\w+)\s*\:\s*(\([^\)]*\))?\s*[=-]\>/
                        if m?[1]?
                            _.set @classes, "#{currentClass}.methods.#{m[1]}", 
                                line: li
                                
                            funcInfo = 
                                line:  li
                                file:  file
                                class: currentClass
                            
                            funcName = m[1]
                            if funcName.startsWith '@'
                                funcName = funcName.slice 1 
                                funcInfo.static = true
                                
                            funcInfos = @funcs[funcName] ? []
                            funcInfos.push funcInfo
                            @funcs[funcName] = funcInfos
                                                        
                            funcStack.push [indent, funcInfo, funcName]
                            
                            funcAdded = true
                    else
                        currentClass = null if indent < 4
                        m = line.match /^\s*([\w\.]+)\s*[\:\=]\s*(\([^\)]*\))?\s*[=-]\>/
                        if m?[1]?
                            
                            funcInfo = 
                                line: li
                                file: file
                                
                            funcInfos = @funcs[m[1]] ? []
                            funcInfos.push funcInfo
                            @funcs[m[1]] = funcInfos
                                                        
                            funcStack.push [indent, funcInfo, m[1]]
                            funcAdded = true

                words = line.split @splitRegExp
                for word in words
                    _.update @words, "#{word}.count", (n) -> (n ? 0) + 1 
                    
                    switch word
                        when 'class'
                            m = line.match /^\s*class\s+(\w+)(\s+extends\s\w+)?/
                            if m?[1]?
                                currentClass = m[1]
                                _.set @classes, "#{m[1]}", 
                                    file: file
                                    line: li
                        when 'require'
                            m = line.match /^\s*([\w\{\}]+)\s+=\s+require\s+[\'\"]([\.\/\w]+)[\'\"]/
                            if m?[1]? and m[2]?
                                r = fileInfo.require ? []
                                r.push [m[1], m[2]]
                                fileInfo.require = r
                                
                                abspath = resolve path.join path.dirname(file), m[2] 
                                abspath += '.coffee'
                                if (m[2][0] == '.') and (not @files[abspath]?) and (@queue.indexOf(abspath) < 0)
                                    if fileExists abspath 
                                        @queue.push abspath
                        when "#include"
                            m = line.match /^#include\s+[\"\<]([\.\/\w]+)[\"\>]/
                            if m?[1]?
                                r = fileInfo.require ? []
                                r.push [null, m[1]]
                                fileInfo.require = r
                                abspath = resolve path.join path.dirname(file), m[1] 
                                abspath += '.coffee' if not path.extname m[1]
                                if not @files[abspath]? and @queue.indexOf(abspath) < 0
                                    if fileExists abspath 
                                        log "queue", abspath
                                        @queue.push abspath
            if funcAdded
                
                while funcStack.length
                    last(funcStack)[1].last = li - 1
                    funcInfo = funcStack.pop()    
                    fileInfo.funcs.push [funcInfo[1].line, funcInfo[1].last, funcInfo[2], funcInfo[1].class ? path.basename file, path.extname file]
                
                for win in BrowserWindow.getAllWindows()
                    win.webContents.send 'funcsCount', Object.keys(@funcs).length
                    
            @files[file] = fileInfo

            for win in BrowserWindow.getAllWindows()
                win.webContents.send 'filesCount', Object.keys(@files).length
                    
            if @queue.length
                file = @queue.shift()
                @indexFile file
                        
module.exports = Indexer
