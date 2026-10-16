/* 0: left bank, 1: right bank. */
bool all_right_side = false;
bool w_and_g = false;
bool g_and_c = false;

/* Solved */
#define fin (all_right_side == true)
/* Wolf ate goat */
#define wg  (w_and_g == false)
/* Goat ate cabbage */
#define gc  (g_and_c == false)

/* A counterexample is a safe sequence of crossings reaching the goal. */
ltl no_solution { !((<> fin) && ([] (wg && gc))) }

active proctype river()
{
    /* Everyone on left bank at start */
    bit f = 0, w = 0, g = 0, c = 0;

    do
    /* If everyone is on right bank */
    :: (f == 1 && w == 1 && g == 1 && c == 1) ->
        all_right_side = true;
        break
    :: else ->
        /* Use atomic: observe completed crossings, not intermediate assignments. */
        atomic {
            if
            /* Farmer + wolf */
            :: (f == w) -> f = 1-f; w = 1-w;
                printf("Cross with wolf: f=%d w=%d g=%d c=%d\n", f, w, g, c)
            /* Farmer + goat */
            :: (f == g) -> f = 1-f; g = 1-g;
                printf("Cross with goat: f=%d w=%d g=%d c=%d\n", f, w, g, c)
            /* Farmer + cabbage */
            :: (f == c) -> f = 1-f; c = 1-c;
                printf("Cross with cabbage: f=%d w=%d g=%d c=%d\n", f, w, g, c)
            /* Solo farmer */
            :: true -> f = 1-f;
                printf("Cross alone: f=%d w=%d g=%d c=%d\n", f, w, g, c)
            fi;

            /* Wolf eats goat */
            if
            :: (f != w && w == g) -> w_and_g = true
            :: else -> skip
            fi;

            /* Goat eats cabbage */
            if
            :: (f != g && g == c) -> g_and_c = true
            :: else -> skip
            fi
        }
    od;
    printf("All on the right bank. wolf_ate_goat=%d goat_ate_cabbage=%d\n",
           w_and_g, g_and_c)
}
