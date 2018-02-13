def calculate(generously, amount, hand_out=1):
    paid = []
    while sum(paid) + hand_out <= amount:
        paid.append(hand_out)
        if generously:
            hand_out *= 2
        else:
            hand_out = 1 if len(paid) < 2 else paid[-2]+paid[-1]

    if sum(paid) < amount:
        leftover = amount - sum(paid)
        if validate(lefover, paid):
            paid.append(leftover)

    return len(paid)

def validate(num, paid):
    if num > paid[-1]*2 :
        retrun False
    if len(paid) >= 2 and num < paid[-2] + paid[-1]:
        return False

    return True

def answer(total_lambs):
    return (calculate(False, total_lambs, 1) -
            calculate(True, total_lambs, 1))

print "10:  %s" % answer(10)
print "====================================="
print "143: %s" % answer(143)
print "====================================="
print "1: %s" % answer(1)
print "====================================="
print "10000000000: %s" % answer(10000000000)
print "====================================="
print "0: %s" % answer(0)
print "====================================="
print "376: %s" % answer(376)
print "====================================="

