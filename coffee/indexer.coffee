# 000  000   000  0000000    00000000  000   000  00000000  00000000
# 000  0000  000  000   000  000        000 000   000       000   000
# 000  000 0 000  000   000  0000000     00000    0000000   0000000
# 000  000  0000  000   000  000        000 000   000       000   000
# 000  000   000  0000000    00000000  000   000  00000000  000   000
{
packagePath,
fileExists,
unresolve,
fileName,
resolve,
log
}        = require 'kxk'
Walker   = require './tools/walker'
_        = require 'lodash'
fs       = require 'fs'
path     = require 'path'
electron = require 'electron'

BrowserWindow = electron.BrowserWindow

class Indexer

    @requireRegExp = /^\s*([\w\{\}]+)\s+=\s+require\s+[\'\"]([\.\/\w]+)[\'\"]/
    @classRegExp   = /^\s*class\s+(\w+)(\s+extends\s\w+.*|\s*:\s*[\w\,\s\<\>]+)?\s*$/
    @includeRegExp = /^#include\s+[\"\<]([\.\/\w]+)[\"\>]/
    @methodRegExp  = /^\s+([\@]?\w+)\s*\:\s*(\([^\)]*\))?\s*[=-]\>/
    @funcRegExp    = /^\s*([\w\.]+)\s*[\:\=]\s*(\([^\)]*\))?\s*[=-]\>/
    @splitRegExp   = new RegExp "[^\\w\\d\\_]+", 'g'

    constructor: () ->
        @collectBins()
        @collectProjects()
        @dirs    = Object.create null
        @files   = Object.create null
        @classes = Object.create null
        @funcs   = Object.create null
        @words   = Object.create null
        @walker  = null
        @queue   = []

    @testWord: (word) ->
        switch
            when word.length < 3 then false # exclude when too short
            when word[0] in ['-', "#"] then false
            when word[word.length-1] == '-' then false 
            when word[0] == '_' and word.length < 4 then false # exclude when starts with underscore and is short
            when /^[0\_\-\@\#]+$/.test word then false # exclude when consist of special characters only
            when /\d/.test word then false # exclude when word contains number
            else true

    collectBins: ->
        @bins = []
        for dir in ['/bin', '/usr/bin', '/usr/local/bin']
            w = new Walker
                maxFiles:    1000
                root:        dir
                includeDirs: false
                includeExt:  [''] # report files without extension
                file:        (p) => @bins.push path.basename p
            w.start()

    collectProjects: ->
        @projects = {}
        w = new Walker
            maxFiles:    5000
            maxDepth:    3
            root:        resolve '~'
            include:     ['.git']
            ignore:      ['node_modules', 'img', 'bin', 'js', 'Library']
            skipDir:     (p) -> path.basename(p) == '.git'
            filter:      (p) -> path.extname(p) not in ['.noon', '.json', '.git', '']
            dir:         (p) => if path.basename(p) == '.git' then @projects[path.basename path.dirname p] = dir: unresolve path.dirname p
            file:        (p) => if fileName(p) == 'package' then @projects[path.basename path.dirname p] = dir: unresolve path.dirname p
        w.start()

    # 000  000   000  0000000    00000000  000   000        0000000    000  00000000
    # 000  0000  000  000   000  000        000 000         000   000  000  000   000
    # 000  000 0 000  000   000  0000000     00000          000   000  000  0000000
    # 000  000  0000  000   000  000        000 000         000   000  000  000   000
    # 000  000   000  0000000    00000000  000   000        0000000    000  000   000

    indexDir: (dir) ->

        return if not dir? or @dirs[dir]?
        @dirs[dir] =
            name: path.basename dir

        wopt =
            root:        dir
            includeDir:  dir
            includeDirs: true
            dir:         @onWalkerDir
            file:        @onWalkerFile
            done:        @shiftQueue

        @walker = new Walker wopt
        @walker.cfg.ignore.push 'js'
        @walker.start()

    onWalkerDir: (p, stat) =>
        if not @dirs[p]?
            @dirs[p] =
                name: path.basename p

    onWalkerFile: (p, stat) =>
        if not @files[p]? and @queue.indexOf(p) < 0
            if stat.size < 654321 # obviously some arbitrary number :)
                @queue.push p
            else
                log "warning! file #{p} too large? #{stat.size}. skipping indexing!"

    #  0000000   0000000    0000000        00000000  000   000  000   000   0000000  
    # 000   000  000   000  000   000      000       000   000  0000  000  000       
    # 000000000  000   000  000   000      000000    000   000  000 0 000  000       
    # 000   000  000   000  000   000      000       000   000  000  0000  000       
    # 000   000  0000000    0000000        000        0000000   000   000   0000000  

    addFuncInfo: (funcName, funcInfo) ->
        if funcName.startsWith '@'
            funcName = funcName.slice 1
            funcInfo.static = true
            
        funcInfo.name = funcName
        
        funcInfos = @funcs[funcName] ? []
        funcInfos.push funcInfo
        @funcs[funcName] = funcInfos
        
        funcInfo

    addMethod: (className, funcName, file, li) ->

        funcInfo = @addFuncInfo funcName,
            line:  li
            file:  file
            class: className

        _.set @classes, "#{className}.methods.#{funcInfo.name}", funcInfo

        funcInfo

    # 00000000   00000000  00     00   0000000   000   000  00000000        00000000  000  000      00000000
    # 000   000  000       000   000  000   000  000   000  000             000       000  000      000
    # 0000000    0000000   000000000  000   000   000 000   0000000         000000    000  000      0000000
    # 000   000  000       000 0 000  000   000     000     000             000       000  000      000
    # 000   000  00000000  000   000   0000000       0      00000000        000       000  0000000  00000000

    removeFile: (file) ->
        return if not @files[file]?
        for name,infos of @funcs
            _.remove infos, (v) -> v.file == file
            delete @funcs[name] if not infos.length
        @classes = _.omitBy @classes, (v) -> v.file == file
        delete @files[file]

    # 000  000   000  0000000    00000000  000   000        00000000  000  000      00000000
    # 000  0000  000  000   000  000        000 000         000       000  000      000
    # 000  000 0 000  000   000  0000000     00000          000000    000  000      0000000
    # 000  000  0000  000   000  000        000 000         000       000  000      000
    # 000  000   000  0000000    00000000  000   000        000       000  0000000  00000000

    indexFile: (file, opt) ->

        @removeFile file if opt?.refresh

        return @shiftQueue() if @files[file]?

        isCpp = path.extname(file) in ['.cpp', '.cc']
        isHpp = path.extname(file) in ['.hpp', '.h' ]

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

                    while funcStack.length and indent <= _.last(funcStack)[0]
                        _.last(funcStack)[1].last = li - 1
                        funcInfo = funcStack.pop()
                        fileInfo.funcs.push [
                            funcInfo[1].line
                            funcInfo[1].last
                            funcInfo[2]
                            funcInfo[1].class ? path.basename file, path.extname file
                        ]

                    if currentClass? and indent == 4

                        # 00     00  00000000  000000000  000   000   0000000   0000000     0000000
                        # 000   000  000          000     000   000  000   000  000   000  000
                        # 000000000  0000000      000     000000000  000   000  000   000  0000000
                        # 000 0 000  000          000     000   000  000   000  000   000       000
                        # 000   000  00000000     000     000   000   0000000   0000000    0000000

                        m = line.match Indexer.methodRegExp
                        if m?[1]?
                            funcName = m[1]
                            funcInfo = @addMethod currentClass, funcName, file, li
                            funcStack.push [indent, funcInfo, funcInfo.name]
                            funcAdded = true
                    else

                        if isCpp or isHpp
                            methodRegExp = /(\w+)(\<[^\>]+\>)?\:\:(\w+)\s*(\([^\)]*\))\s*(const)?$/
                            m = line.match methodRegExp
                            if m?[1]? and m?[3]?
                                className = m[1]
                                funcName  = m[3]
                                funcInfo = @addMethod className, funcName, file, li
                                funcStack.push [indent, funcInfo, funcInfo.name]
                                funcAdded = true
                                continue

                        # 00000000  000   000  000   000   0000000  000000000  000   0000000   000   000   0000000
                        # 000       000   000  0000  000  000          000     000  000   000  0000  000  000
                        # 000000    000   000  000 0 000  000          000     000  000   000  000 0 000  0000000
                        # 000       000   000  000  0000  000          000     000  000   000  000  0000       000
                        # 000        0000000   000   000   0000000     000     000   0000000   000   000  0000000

                        currentClass = null if indent < 4
                        m = line.match Indexer.funcRegExp
                        if m?[1]?

                            funcInfo = @addFuncInfo m[1],
                                line: li
                                file: file

                            funcStack.push [indent, funcInfo, funcInfo.name]
                            funcAdded = true

                words = line.split Indexer.splitRegExp
                for word in words
                    
                    if Indexer.testWord word
                        _.update @words, "#{word}.count", (n) -> (n ? 0) + 1

                    switch word

                        #  0000000  000       0000000    0000000   0000000
                        # 000       000      000   000  000       000
                        # 000       000      000000000  0000000   0000000
                        # 000       000      000   000       000       000
                        #  0000000  0000000  000   000  0000000   0000000
                        
                        when 'class'
                            m = line.match Indexer.classRegExp
                            if m?[1]?
                                currentClass = m[1]
                                _.set @classes, "#{m[1]}.file", file
                                _.set @classes, "#{m[1]}.line", li

                        # 00000000   00000000   0000000   000   000  000  00000000   00000000
                        # 000   000  000       000   000  000   000  000  000   000  000
                        # 0000000    0000000   000 00 00  000   000  000  0000000    0000000
                        # 000   000  000       000 0000   000   000  000  000   000  000
                        # 000   000  00000000   00000 00   0000000   000  000   000  00000000
                        
                        when 'require'
                            m = line.match Indexer.requireRegExp
                            if m?[1]? and m[2]?
                                r = fileInfo.require ? []
                                r.push [m[1], m[2]]
                                fileInfo.require = r
                                abspath = resolve path.join path.dirname(file), m[2]
                                abspath += '.coffee'
                                if (m[2][0] == '.') and (not @files[abspath]?) and (@queue.indexOf(abspath) < 0)
                                    if fileExists abspath
                                        @queue.push abspath

                        #  00  00   000  000   000   0000000  000      000   000  0000000    00000000
                        # 00000000  000  0000  000  000       000      000   000  000   000  000
                        #  00  00   000  000 0 000  000       000      000   000  000   000  0000000
                        # 00000000  000  000  0000  000       000      000   000  000   000  000
                        #  00  00   000  000   000   0000000  0000000   0000000   0000000    00000000
                        
                        when '#include'
                            m = line.match Indexer.includeRegExp
                            if m?[1]?
                                r = fileInfo.require ? []
                                r.push [null, m[1]]
                                fileInfo.require = r
                                abspath = resolve path.join path.dirname(file), m[1]
                                abspath += '.coffee' if not path.extname m[1]
                                if not @files[abspath]? and @queue.indexOf(abspath) < 0
                                    if fileExists abspath
                                        @queue.push abspath
            if funcAdded

                while funcStack.length
                    _.last(funcStack)[1].last = li - 1
                    funcInfo = funcStack.pop()
                    fileInfo.funcs.push [funcInfo[1].line, funcInfo[1].last, funcInfo[2], funcInfo[1].class ? path.basename file, path.extname file]

                for win in BrowserWindow.getAllWindows()
                    win.webContents.send 'classesCount', _.size @classes
                    win.webContents.send 'funcsCount',   _.size @funcs

            @files[file] = fileInfo

            for win in BrowserWindow.getAllWindows()
                win.webContents.send 'filesCount', _.size @files

            @indexDir path.dirname file
            @indexDir packagePath file

            @shiftQueue()

    shiftQueue: =>
        if @queue.length
            file = @queue.shift()
            @indexFile file

module.exports = Indexer
