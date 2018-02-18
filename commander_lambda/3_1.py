def find_valid_moves(maze, position):
    (y, x) = position
    return [ (y+dy, x+dx ) for (dy, dx)
            in [(1, 0), (0, 1), (-1,0), (0, -1)]
            if not (x+dx >= len(maze[-1]) or y+dy >= len(maze)
                    or x+dx < 0 or y+dx < 0 or maze[y+dy][x+dx] == 1) ]

def build_graph(maze, graph = {}):
    x,y = (0,0)
    for row in maze:
        for item in row:
            if item == 0:
                validMoves = find_valid_moves(maze, (y,x))
                if (y,x) in graph:
                    graph[str((y,x))] += validMoves
                else:
                    graph[str((y,x))] = validMoves
            x += 1
        x = 0
        y += 1
    return graph

def find_shortest_path(graph, start, end, path=[]):
    path = path + [start]
    if start == end:
        return path
    if not graph.has_key(str(start)):
        return None

    shortest = None
    for node in graph[str(start)]:
        if node not in path:
            newpath = find_shortest_path(graph, node, end, path)
            if newpath:
                if not shortest or len(newpath) < len(shortest):
                    shortest = newpath
    print shortest
    return shortest

def find_all_paths(graph, start, end, path=[]):
    path = path + [start]
    if start == end:
        return [path]
    if not graph.has_key(str(start)):
        return []
    paths = []
    for node in graph[str(start)]:
        if node not in path:
            newpaths = find_all_paths(graph, node, end, path)
            for newpath in newpaths:
                print newpath
                paths.append(newpath)
    return paths

def find_breakable_walls(maze):
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

def set_the_wall(maze, wall, state=0):
    (y, x) = wall
    tmp = []
    for row in maze:
        tmp.append(row[:])
    tmp[y][x] = state
    return tmp

def answer(maze):
    lengths = []
    paths = []
    max_y = len(maze) - 1
    max_x = len(maze[-1]) - 1

    graph = build_graph(maze)
    paths.append(find_shortest_path(graph, (0,0), (max_y,max_x)))

    replanned_mazes = [ set_the_wall(maze, wall)
                      for wall in find_breakable_walls(maze) ]
    paths +=  [ find_shortest_path(build_graph(m), (0,0), (max_y,max_x))
               for m in replanned_mazes ]
    for path in paths:
        if path is not None:
            print path
            lengths.append(len(path))
    return min(lengths)
    
maze = [[0, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 1, 0],
        [0, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 1, 1],
        [0, 1, 1, 1, 1, 1],
        [0, 0, 0, 0, 0, 0]]

#maze = [[0, 1, 1, 0],
#        [0, 0, 0, 1],
#        [1, 1, 0, 0],
#        [1, 1, 1, 0]]
#maze = [[0,1,1],
#	[0,1,1],
#       [1,0,0]]
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
#        [0, 1, 0, 0, 0],
#        [0, 1, 0, 1, 1],
#        [0, 1, 1, 1, 1],
#        [0, 0, 0, 0, 0]]

maze = [[0, 1, 1, 1, 1, 1, 1, 0, 0, 0],
[0, 1, 0, 0, 0, 0, 1, 1, 0, 0],
[0, 1, 0, 0, 0, 0, 0, 1, 1, 0],
[0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
[0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
[0, 0, 0, 0, 0, 0, 0, 0, 1, 0],
[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
[0, 1, 1, 1, 1, 0, 0, 0, 0, 0],
[0, 1, 1, 1, 1, 0, 0, 0, 0, 0],
[0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]

#maze = [[0, 1, 1, 1, 1, 0],
#        [0, 1, 0, 0, 1, 0],
#        [0, 0, 0, 0, 0, 0],
#        [0, 0, 0, 0, 0, 0],
#        [0, 0, 0, 0, 0, 0],
#        [0, 1, 1, 1, 0, 0],
#        [0, 1, 1, 1, 0, 0],
#        [0, 0, 0, 0, 0, 0]]
for i in maze:
    print i
print "============================="

print answer(maze)
