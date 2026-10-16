#define N 128
#define size 16

chan ch = [size] of {short};
chan large = [size] of {short};
chan small = [size] of {short};

proctype split()
{
    short data;

    do
    :: ch ? data ->
        if
        :: (data >= N) -> large ! data
        :: (data < N) -> small ! data
        fi
    od;
}

proctype merge()
{
    short data;

    do
    :: large ? data -> ch ! data
    :: small ? data -> ch ! data
    od;
}

init
{
    ch ! 130;
    ch ! 12;
    run split();
    run merge();
}
