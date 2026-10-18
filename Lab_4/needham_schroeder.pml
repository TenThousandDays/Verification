/* Lowe protocol model, with Intruder role */

mtype = {
    msg,
    alice, bob, intruder,
    pkA, pkB, pkI,
    nonceA, nonceB, nonceI,
    ok, err
};

typedef mesCrypt {
    mtype s;      /* Sender (open part). */
    mtype r;      /* Receiver (open part). */
    mtype nummsg; /* Message number: 1, 2 or 3 (open part). */
    mtype key;    /* Public key used to encrypt the payload. */
    mtype d1;     /* First encrypted field. */
    mtype d2;     /* Second encrypted field. */
}

chan fakedA = [0] of { mtype, mesCrypt };
chan fakedB = [0] of { mtype, mesCrypt };
chan intercepted = [0] of { mtype, mesCrypt };

mtype partnerA, partnerB;
mtype statusA, statusB;
bool knowNA, knowNB;

active proctype Alice()
{
    mtype pkey, pnonce;
    mesCrypt data;

    statusA = err;
    if
    :: partnerA = bob; pkey = pkB
    :: partnerA = intruder; pkey = pkI
    fi;

    /* Message 1: A -> partner: {A, nonceA}_partner. */
    d_step {
        data.s = alice;
        data.r = partnerA;
        data.nummsg = 1;
        data.key = pkey;
        data.d1 = alice;
        data.d2 = nonceA
    }
    intercepted!msg(data);

    fakedA?msg(data);
end_errA:
    if
    :: (data.key == pkA) && (data.d1 == nonceA) &&
       (data.s == partnerA) && (data.r == alice) &&
       (data.nummsg == 2) -> pnonce = data.d2
    :: else -> goto stopA
    fi;

    /* Message 3: A -> partner: {partner's nonce}_partner. */
    d_step {
        data.s = alice;
        data.r = partnerA;
        data.nummsg = 3;
        data.key = pkey;
        data.d1 = pnonce;
        data.d2 = 0
    }
    intercepted!msg(data);
    statusA = ok;
stopA:
    printf("MSC: Process A finished\n")
}

active proctype Bob()
{
    mtype pkey, pnonce;
    mesCrypt data;

    statusB = err;
    fakedB?msg(data);
end_errB1:
    if
    :: (data.r == bob) && (data.key == pkB) &&
       (data.s == data.d1) && (data.nummsg == 1) ->
        partnerB = data.s;
        pnonce = data.d2
    :: else -> goto stopB
    fi;

    if
    :: partnerB == alice -> pkey = pkA
    :: partnerB == intruder -> pkey = pkI
    :: else -> goto stopB
    fi;

    /* Message 2: B -> partner: {partner's nonce, nonceB}_partner. */
    d_step {
        data.s = bob;
        data.r = partnerB;
        data.nummsg = 2;
        data.key = pkey;
        data.d1 = pnonce;
        data.d2 = nonceB
    }
    intercepted!msg(data);

    fakedB?msg(data);
end_errB2:
    if
    :: (data.r == bob) && (data.s == partnerB) &&
       (data.key == pkB) && (data.d1 == nonceB) &&
       (data.nummsg == 3) -> statusB = ok
    :: else -> goto stopB
    fi;
stopB:
    printf("MSC: Process B finished\n")
}

active proctype Intruder()
{
    mesCrypt data, fake;

    knowNA = false;
    knowNB = false;
end:
    do
    :: intercepted?msg(data) ->
        if
        :: data.key == pkI ->
            if
            :: (data.d1 == nonceA || data.d2 == nonceA) -> knowNA = true
            :: (data.d1 == nonceB || data.d2 == nonceB) -> knowNB = true
            fi
        :: else -> skip
        fi;

        /* Construct the open part and choose an encryption key. */
        if
        :: fake.s = alice ->
            fake.r = bob;
            fake.key = pkB
        :: fake.s = bob ->
            fake.r = alice;
            fake.key = pkA
        :: fake.s = intruder ->
            if
            :: fake.r = bob; fake.key = pkB
            :: fake.r = alice; fake.key = pkA
            fi
        fi;

        /* A secret nonce can be inserted only if it is known. */
        if
        :: fake.d1 = alice
        :: fake.d1 = bob
        :: fake.d1 = intruder
        :: fake.d1 = nonceI
        :: knowNA -> fake.d1 = nonceA
        :: knowNB -> fake.d1 = nonceB
        fi;

        if
        :: fake.d2 = alice
        :: fake.d2 = bob
        :: fake.d2 = intruder
        :: fake.d2 = nonceI
        :: knowNA -> fake.d2 = nonceA
        :: knowNB -> fake.d2 = nonceB
        fi;

        /* An unreadable encrypted payload can only be copied unchanged. */
        if
        :: data.key != pkI ->
            fake.key = data.key;
            fake.d1 = data.d1;
            fake.d2 = data.d2
        :: else -> skip
        fi;

        if
        :: fake.nummsg = 1
        :: fake.nummsg = 2
        :: fake.nummsg = 3
        fi;

        /* Forward the intercepted message or inject the forged message. */
        if
        :: data.r == alice -> fakedA!msg(data)
        :: data.r == bob -> fakedB!msg(data)
        :: fake.r == alice -> fakedA!msg(fake)
        :: fake.r == bob -> fakedB!msg(fake)
        fi
    od
}

/* Attack conditions claim */
#define agentB_finished (statusB == ok)
#define bobtrustsA      (partnerB == alice)
#define intrknowNA     (knowNA == true)
#define intrknowNB     (knowNB == true)

ltl no_attack {
    ! (<> (agentB_finished && bobtrustsA && intrknowNA && intrknowNB))
}
