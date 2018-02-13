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
        if validate(leftover, paid):
            paid.append(leftover)

    return len(paid)

def validate(num, paid):
    if num > paid[-1]*2 :
        return False
    if len(paid) >= 2 and num < paid[-2] + paid[-1]:
        return False

    return True

def answer(total_lambs):
    return (calculate(False, total_lambs, 1) -
            calculate(True, total_lambs, 1))

for i in [10, 143, 1, 100000000000, 0, 9, 376]:
    print "%s:  %s" % (i, answer(i))
    print "====================================="
