mtype = {msg};
chan to_first = [2] of {mtype, bit};
chan to_second = [2] of {mtype, bit};
chan to_third = [2] of {mtype, bit};

active proctype First()
{
again:
    to_second ! msg, 1;
    to_first ? msg, 1;
    to_second ! msg, 0;
    to_first ? msg, 0;
    goto again;
}

active proctype Second()
{
again:
    to_second ? msg, 1;
    to_third ! msg, 1;
    to_second ? msg, 0;
    to_third ! msg, 0;
    goto again;
}

active proctype Third()
{
again:
    to_third ? msg, 1;
    to_first ! msg, 1;
    to_third ? msg, 0;
    to_first ! msg, 0;
    goto again;
}
