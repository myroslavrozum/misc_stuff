def isValidMove(maze, move):
    (y, x) = move
    return not (x >= len(maze[0]) or y >= len(maze)
                or x < 0 or y < 0 or maze[y][x] == 1)

def setTheWall(m, wall, state=0):
    (y, x) = wall
    tmp = []
    for row in m:
        tmp.append(row[:])
    tmp[y][x] = state
    return tmp

def findValidMoves(maze, position):
    (y, x) = position
    return [ (y+dy, x+dx ) for (dy, dx)
            in [(1, 0), (0, 1), (-1,0), (0, -1)]
            if isValidMove(maze, (y+dy, x+dx))]

def findPath(maze, visited=[], position=(0,0)):
    m_y = len(maze)-1
    m_x = len(maze[0])-1
    validMoves = filter(lambda x: x not in visited, findValidMoves(maze, position))
    visited.append(position)
    if position == (m_y,m_x):
        print "FOUND Position: %s, Visited: %s" % (position, visited)
        return visited
    if len(validMoves) == 0:
        print "STUCK at %s, Visited: %s" % (str(position), visited)
        position = findTheFork(maze, visited)
        if position is None:
            return
        visited.append(position)
        print "forkAt: %s at %s" % (str(position), visited.index(position))
        for r in maze:
            print r
    validMoves = filter(lambda x: x not in visited, findValidMoves(maze, position))
    for move in validMoves:
        print "Position: %s, Moves: %s, Visited: %s" % (position, validMoves, visited)
        return visited if move in visited else findPath(maze, visited, move)

def findTheFork(maze, visited, previous=(0,0)):
    if len(visited) == 0:
        return
    position = visited[-1]
    validMoves = findValidMoves(maze, position)
    notVisited = [ m for m in validMoves if m not in visited and m != previous ]
    return position if len(notVisited) > 0 else findTheFork(maze, visited[:-1], position)

def findBreakableWalls(maze):
    m = len(maze)
    breakable = []
    if m < 2:
        return breakable

    x,y = (0,0)
    max_y = len(maze) - 1
    for row in maze:
        max_x = len(row) - 1
        for item in row:
            if item == 1:
                if y < max_y and y > 0 and maze[y-1][x] == 0 and maze[y+1][x] == 0:
                    breakable.append((y,x))
                if x < max_x and x > 0 and maze[y][x-1] == 0 and maze[y][x+1] == 0:
                    breakable.append((y,x))
                if ( y == max_y and x == 0 and maze[y-1][x] == 0 and maze[y][x+1] == 0):
                    breakable.append((y,x))
                if ( y == 0 and x == max_x and maze[y][x-1] == 0 and maze[y+1][x] == 0):
                    breakable.append((y,x))
            x += 1
        x = 0
        y += 1

    return breakable

def normalize(maze):
    x,y = (0,0)
    results = []
    forks = []
    for row in maze:
        for item in row:
            if item != 1:
                validMoves = findValidMoves(maze, (y,x))
                if len(validMoves) > 2:
                    forks.append(validMoves)
            x += 1
        x = 0
        y += 1
    d = {}
    print forks
    for f in forks:
        for wall in f:
            y,x = wall
            if x in d:
                d[x].append(y)
            else:
                d[x] = [y]
    for k in d:
        tmp_maze = maze[:]
        if len(d[k]) > 1:
            tmp_maze = setTheWall(tmp_maze, (d[k][0], k), 1)
            tmp_maze = setTheWall(tmp_maze, (d[k][1], k), 1)
            results.append(tmp_maze)

    return results

def answer(maze):
    paths = [findPath(maze, [])]
    paths +=  [ findPath(m, []) for m in normalize(maze) ]
    replannedMazes = [ setTheWall(maze, wall) for wall in findBreakableWalls(maze) ]
    paths +=  [ findPath(m, []) for m in replannedMazes ]
    lengths = [ len(p) for p in paths if p is not None]
    if len(lengths) > 0:
        return min(lengths)

maze = [[0, 0, 0, 0, 0, 0],
        [1, 1, 1, 1, 1, 0],
        [0, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 1, 1],
        [0, 1, 1, 0, 1, 1],
        [0, 0, 0, 0, 0, 0]]

#maze = [[0, 1, 1, 0],
#        [0, 0, 0, 1],
#        [1, 1, 0, 0],
#        [1, 1, 1, 0]]
##
#maze = [[0,1,1],
#	[0,1,1],
#      [1,0,0]]
##
#maze = [[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
#        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
#        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
#        [0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
#        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]
#
#maze = [[0, 0, 0, 0, 0],
#        [1, 1, 1, 1, 0],
#        [0, 0, 0, 0, 0],
#        [0, 1, 0, 1, 1],
#        [0, 1, 1, 1, 1],
#        [0, 0, 0, 0, 0]]
for i in maze:
    print i
print "============================="

print answer(maze)
#normalize(maze)
