#!/usr/bin/env python
a = [[[111,111],1], [2,2], [3,3], [4,4]]

def x(y):
    if isinstance(y, int):
        print y
        return
    else:
        for i in y:
            x(i)

x(a)
