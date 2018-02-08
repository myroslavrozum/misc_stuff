#!/usr/bin/env python
'''
| 0| 1| 2| 3| 4| 5| 6| 7|
-------------------------
| 8| 9|10|11|12|13|14|15|
-------------------------
|16|17|18|19|20|21|22|23|
-------------------------
|24|25|26|27|28|29|30|31|
-------------------------
|32|33|34|35|36|37|38|39|
-------------------------
|40|41|42|43|44|45|46|47|
-------------------------
|48|49|50|51|52|53|54|55|
-------------------------
|56|57|58|59|60|61|62|63|
-------------------------
'''

def drop_the_bomb(srcs, dst, visited=[], iteration=0):
    board_min = 0
    board_max = 63
    global paths
    iteration += 1
    poi = []
    for src in srcs:
        if src%8 == 0:
            directions = [ -15, 17, -6, 10 ]
        elif src%8 == 1:
            directions = [ -15, 15, -17, 17, 10, -6 ]
        elif (src+1)%8 == 0:
            directions = [ -10, 6, -17, 15 ]
        elif (src+2)%8 == 0:
            directions = [ -15, 15, -17, 17, -10, 6 ]
        else:
            directions = [-15, 15, -17, 17, -10, 10, -6, 6]
    
        poi += filter( lambda p: p not in visited and
                     p >= board_min and
                     p <= board_max,
                     map(lambda d: src + d, directions))
        
        visited.append(src)
    if dst in poi:
        #paths = iteration if ( iteration < paths or paths == 0 ) else paths
        return iteration
    else:
        return drop_the_bomb(poi, dst, visited, iteration)
    visited = []

def answer(src, dst):
    print "Path: %s ==> %s" % (src, dst)
    print x([src], dst)

#answer(19, 36)
#answer(9, 36)
#answer(0, 1)
#answer(0, 3)
#answer(19, 30)
#answer(0, 61)
