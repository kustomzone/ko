#  0000000  000   000  000   000  000000000   0000000   000   000
# 000        000 000   0000  000     000     000   000   000 000 
# 0000000     00000    000 0 000     000     000000000    00000  
#      000     000     000  0000     000     000   000   000 000 
# 0000000      000     000   000     000     000   000  000   000

fs     = require 'fs'
path   = require 'path'
noon   = require 'noon'
log    = require '../tools/log'
matchr = require '../tools/matchr'

class syntax
    
    @matchrConfigs = {}
    @syntaxNames = []

    constructor: (@editor) ->
        @name ='txt'
        @diss = []
        
    #  0000000  000   000   0000000   000   000   0000000   00000000  0000000  
    # 000       000   000  000   000  0000  000  000        000       000   000
    # 000       000000000  000000000  000 0 000  000  0000  0000000   000   000
    # 000       000   000  000   000  000  0000  000   000  000       000   000
    #  0000000  000   000  000   000  000   000   0000000   00000000  0000000  
    
    changed: (changeInfo) ->
        if changeInfo.deleted.length or changeInfo.inserted.length or changeInfo.changed.length
            # log 'syntax.sorded', changeInfo.sorted        
            for [li, change] in changeInfo.sorted
                switch change
                    when 'deleted'  then @diss.splice li, 1
                    when 'inserted' then @diss.splice li, 0, @dissForLineIndex li
                    when 'changed'  then @diss[li] = @dissForLineIndex li
                
    # 00000000    0000000   00000000    0000000  00000000
    # 000   000  000   000  000   000  000       000     
    # 00000000   000000000  0000000    0000000   0000000 
    # 000        000   000  000   000       000  000     
    # 000        000   000  000   000  0000000   00000000
        
    parse: ->
        @diss = []
        for li in [0...@editor.lines]
            log 'parse', li
            @diss.push @dissForLineIndex li
            if li > 10
                break

    dissForLineIndex: (lineIndex) -> 
        syntax.dissForTextAndSyntax @editor.lines[lineIndex], @name

    @dissForTextAndSyntax: (line, n) ->
        matchr.dissect matchr.ranges syntax.matchrConfigs[n], line
        
    getDiss: (li) ->
        # log 'getDiss', li
        while li >= @diss.length
            log 'getDiss', li
            @diss.push @dissForLineIndex @diss.length # insert blanks?
        @diss[li]
        
    # 000  000   000  000  000000000
    # 000  0000  000  000     000   
    # 000  000 0 000  000     000   
    # 000  000  0000  000     000   
    # 000  000   000  000     000   
    
    @init: ->
        syntaxDir = "#{__dirname}/../../syntax/"
        for syntaxFile in fs.readdirSync syntaxDir
            syntaxName = path.basename syntaxFile, '.noon'
            @syntaxNames.push syntaxName
            patterns = noon.load path.join syntaxDir, syntaxFile
            @matchrConfigs[syntaxName] = matchr.config patterns

syntax.init()
module.exports = syntax