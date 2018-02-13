#def calculate(generously, amount, hand_out=1, paid=[]):
#    paid.append(hand_out)
#    if sum(paid) <= amount:
#        if generously:
#            hand_out *= 2
#        else:
#            hand_out = 1 if len(paid) < 2 else paid[-2]+paid[-1]
#        return calculate(generously, amount, hand_out, paid)
#    else:
#        return len(paid)

def calculate(generously, amount, hand_out=1, paid=[]):
    while sum(paid) + hand_out <= amount:
        paid.append(hand_out)
        print paid
        if generously:
            hand_out *= 2
        else:
            hand_out = 1 if len(paid) < 2 else paid[-2]+paid[-1]

    return len(paid)

def answer(total_lambs):
    return (calculate(False, total_lambs, 1, []) -
            calculate(True, total_lambs, 1, []))

#print "10:  %s" % answer(10)
#print "143: %s" % answer(143)
print "1: %s" % answer(1)
#print "10000000000: %s" % answer(10000000000)
#print "0: %s" % answer(0)
#print "376: %s" % answer(376)
#

