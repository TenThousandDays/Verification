#define N 5
#define msgtype 1

chan l_fork[N] = [0] of { bit };
chan r_fork[N] = [0] of { bit };

proctype phil(chan left, right; byte mn)
{
    /*
        0: thinking
        1: hungry (need left fork)
        2: need right fork
        3: eating
        4: returning left fork
        5: returning right fork
    */
    byte cur_state = 0;
    do
    :: cur_state == 0 -> cur_state = 1
    :: cur_state == 1 -> left!msgtype; cur_state = 2
    :: cur_state == 2 -> right!msgtype; cur_state = 3
    :: cur_state == 3 -> cur_state = 4
    :: cur_state == 4 -> left!msgtype; cur_state = 5
    :: cur_state == 5 -> right!msgtype; cur_state = 0
    od
}

proctype fork(chan left_phil, right_phil; byte mn)
{
    /*
        0: free
        1: held by left phil
        2: held by right phil
        Second msg from the owner returns the fork.
    */
    byte cur_state_fork = 0;
end:
    do
    :: cur_state_fork == 0 ->
        if
        :: left_phil?msgtype -> cur_state_fork = 1
        :: right_phil?msgtype -> cur_state_fork = 2
        fi
    :: cur_state_fork == 1 -> left_phil?msgtype; cur_state_fork = 0
    :: cur_state_fork == 2 -> right_phil?msgtype; cur_state_fork = 0
    od
}

init
{
    byte proc;
    proc = 1;
    do
    :: proc <= N ->
        run phil(l_fork[proc - 1], r_fork[proc % N], proc);
        run fork(r_fork[proc % N], l_fork[proc % N], proc);
        proc++
    :: proc > N -> break
    od
}
