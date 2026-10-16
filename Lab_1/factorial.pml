#define N 5

int result = 1;
bool done[N+1];

proctype fact(int n)
{
    if
    :: (n <= 1) -> result = 1
    :: (n >= 2) -> run fact(n-1);
                   /* Wait until child computes (n-1)! */
                   done[n-1];
                   result = n*result;
    fi;
    /* Ready, parent can proceed */
    done[n] = true;
}

init
{
    run fact(N);
    done[N];
    printf("result = %d\n", result)
}
