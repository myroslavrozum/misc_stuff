def x(a, stringg):
    if len(stringg) >= len(a):
        return a if stringg.replace(a,'') == '' else x(a+stringg[0], stringg[1:])

def answer(s):
    pieSlice = x(s[0],s[1:])
    return s.count(pieSlice) if pieSlice else 1

print answer("abccbaabccba")
print "============="
print answer("abcabcabcabc")
print "============="
print answer("abxcabcabcabc")
print "============="
print answer("abcdefghijklnopqrst")
print "============="
print answer("aaaaaaaaaaaaaaaaaaa")

