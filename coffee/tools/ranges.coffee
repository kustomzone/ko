# 00000000    0000000   000   000   0000000   00000000   0000000
# 000   000  000   000  0000  000  000        000       000     
# 0000000    000000000  000 0 000  000  0000  0000000   0000000 
# 000   000  000   000  000  0000  000   000  000            000
# 000   000  000   000  000   000   0000000   00000000  0000000 
    
module.exports = 
    
    #  0000000   0000000   00000000   000000000
    # 000       000   000  000   000     000   
    # 0000000   000   000  0000000       000   
    #      000  000   000  000   000     000   
    # 0000000    0000000   000   000     000   
                
    sort: (rgs) ->
        rgs.sort (a,b) -> 
            if a[0]!=b[0]
                a[0]-b[0]
            else
                if a[1][0]!=b[1][0]
                    a[1][0]-b[1][0]
                else
                    a[1][1]-b[1][1]