#  0000000  000   000  000   000  000000000   0000000   000   000
# 000        000 000   0000  000     000     000   000   000 000 
# 0000000     00000    000 0 000     000     000000000    00000  
#      000     000     000  0000     000     000   000   000 000 
# 0000000      000     000   000     000     000   000  000   000
{
log,
$}     = require 'kxk'
matchr = require '../tools/matchr'
_      = require 'lodash'
path   = require 'path'
noon   = require 'noon'
fs     = require 'fs'

class Syntax
    
    @matchrConfigs = {}
    @syntaxNames = []

    constructor: (@editor) ->
        @name ='txt'
        @diss = []
        @colors = {}

    #  0000000  000      00000000   0000000   00000000 
    # 000       000      000       000   000  000   000
    # 000       000      0000000   000000000  0000000  
    # 000       000      000       000   000  000   000
    #  0000000  0000000  00000000  000   000  000   000

    clear: -> @diss = []

    # 0000000    000   0000000   0000000
    # 000   000  000  000       000     
    # 000   000  000  0000000   0000000 
    # 000   000  000       000       000
    # 0000000    000  0000000   0000000 

    dissForLineIndex: (lineIndex) -> 
        Syntax.dissForTextAndSyntax @editor.line(lineIndex), @name

    @rangesForTextAndSyntax: (line, n) ->
        matchr.ranges Syntax.matchrConfigs[n], line

    @dissForTextAndSyntax: (line, n, opt) ->
        matchr.dissect matchr.ranges(Syntax.matchrConfigs[n], line), opt

    getDiss: (li, opt) ->
        if not @diss[li]?
            rgs = matchr.ranges Syntax.matchrConfigs[@name], @editor.line(li)
            diss = matchr.dissect rgs, opt
            @diss[li] = diss
        @diss[li]
    
    setDiss: (li, dss) ->
        @diss[li] = dss
        @diss[li]
    
    @lineForDiss: (dss) -> 
        l = ""
        for d in dss
            l = _.padEnd l, d.start
            l += d.match
        l
        
    #  0000000   0000000   000       0000000   00000000 
    # 000       000   000  000      000   000  000   000
    # 000       000   000  000      000   000  0000000  
    # 000       000   000  000      000   000  000   000
    #  0000000   0000000   0000000   0000000   000   000
    
    colorForClassnames: (clss) ->
        if not @colors[clss]?
            div = document.createElement 'div'
            div.className = clss
            document.body.appendChild div
            @colors[clss] = window.getComputedStyle(div).color
            div.remove()
        return @colors[clss]

    colorForStyle: (styl) ->
        if not @colors[styl]?
            div = document.createElement 'div'
            div.style = styl
            document.body.appendChild div
            @colors[styl] = window.getComputedStyle(div).color
            div.remove()
        return @colors[styl]

    #  0000000  000   000  00000000  0000000     0000000   000   000   0000000 
    # 000       000   000  000       000   000  000   000  0000  000  000      
    # 0000000   000000000  0000000   0000000    000000000  000 0 000  000  0000
    #      000  000   000  000       000   000  000   000  000  0000  000   000
    # 0000000   000   000  00000000  0000000    000   000  000   000   0000000 
    
    @shebang: (line) ->
        if line.startsWith "#!"
            lastWord = _.last line.split /[\s\/]/
            switch lastWord
                when 'python' then return 'py'
                when 'node'   then return 'js'
                when 'bash'   then return 'sh'
                else 
                    if lastWord in @syntaxNames
                        return lastWord
        'txt'
    
    # 000  000   000  000  000000000
    # 000  0000  000  000     000   
    # 000  000 0 000  000     000   
    # 000  000  0000  000     000   
    # 000  000   000  000     000   
    
    @init: ->
        syntaxDir = "#{__dirname}/../../syntax/"
        for syntaxFile in fs.readdirSync syntaxDir
            syntaxName = path.basename syntaxFile, '.noon'
            patterns = noon.load path.join syntaxDir, syntaxFile
            if patterns.ko?.extnames?
                extnames = patterns.ko.extnames
                delete patterns.ko
                config = matchr.config patterns
                for syntaxName in extnames
                    @syntaxNames.push syntaxName
                    @matchrConfigs[syntaxName] = config
            else
                @syntaxNames.push syntaxName
                @matchrConfigs[syntaxName] = matchr.config patterns

Syntax.init()
module.exports = Syntax
