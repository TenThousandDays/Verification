/* Configuration. Every buyer makes one reservation attempt. */
#define N_SEATS 1
#define N_BUYERS 2

/* Chosen once in init; participants never change these variables. */
byte check_seat;
byte check_buyer;
byte check_booking = 1;
byte check_payment = 1;

mtype = {
    RESERVE, RESERVED, PAY, CANCEL, CHARGE, PAY_OK, PAY_FAIL,
    REFUND, REFUND_OK, START_TIMER, EXPIRE, RESULT,
    FREE, HELD, SOLD,
    UNUSED, ACTIVE, BOUGHT, CANCELLED, EXPIRED, PAYMENT_FAILED,
    NOT_STARTED, PENDING, PAID, FAILED, REFUND_PENDING, REFUNDED,
    NEW, WAIT_RESERVATION, CHOOSING, WAIT_PAYMENT, WAIT_RESULT, DONE,
    READY, PROCESSING, CHARGED, DECLINED, REFUNDING,
    NO_SEAT, TICKET
};

/* Message type, buyer, reservation, payment. Zero means no identifier. */
chan inbox = [N_BUYERS] of { mtype, byte, byte, byte };
/* Message type, reservation, seat, outcome. */
chan replies[N_BUYERS] = [2] of { mtype, byte, byte, mtype };
chan payments[N_BUYERS] = [1] of { mtype };
chan deadlines[N_BUYERS] = [1] of { mtype };

mtype seat_state[N_SEATS] = FREE;
byte seat_booking[N_SEATS];
byte seat_free[N_SEATS] = 1;
byte active_count[N_SEATS];
byte ticket_count[N_SEATS];

/* Reservation and payment identifiers are c + 1 for buyer c. */
mtype booking_state[N_BUYERS + 1] = UNUSED;
mtype payment_state[N_BUYERS + 1] = NOT_STARTED;
byte booking_owner[N_BUYERS + 1];
byte booking_seat[N_BUYERS + 1];
byte payment[N_BUYERS + 1];
bool created[N_BUYERS + 1];
bool booking_active[N_BUYERS + 1];
bool closed_without_ticket[N_BUYERS + 1];
bool issued[N_BUYERS + 1];

/* Payment facts remain true after the corresponding events. */
bool charged[N_BUYERS + 1];
bool returned[N_BUYERS + 1];
bool ticket_for_payment[N_BUYERS + 1];
mtype worker_state[N_BUYERS] = READY;

mtype buyer_state[N_BUYERS] = NEW;
mtype buyer_result[N_BUYERS];
bool requested[N_BUYERS];
bool buyer_done[N_BUYERS];

proctype Buyer(byte c)
{
    mtype kind, outcome;
    byte b, s;

    atomic {
        requested[c] = true;
        buyer_state[c] = WAIT_RESERVATION;
        inbox!RESERVE, c, 0, 0
    }
    replies[c]?kind, b, s, outcome;
    if
    :: kind == RESULT -> goto finish
    :: kind == RESERVED -> buyer_state[c] = CHOOSING
    fi;

    if
    :: atomic {
           inbox!PAY, c, b, b;
           buyer_state[c] = WAIT_PAYMENT
       };
       if
       :: atomic {
              inbox!CANCEL, c, b, 0;
              buyer_state[c] = WAIT_RESULT
          }
       :: skip /* Wait for payment without cancelling. */
       fi
    :: atomic {
           inbox!CANCEL, c, b, 0;
           buyer_state[c] = WAIT_RESULT
       }
    :: replies[c]?RESULT, b, s, outcome -> goto finish
    fi;
    replies[c]?RESULT, b, s, outcome;

finish:
    atomic {
        buyer_result[c] = outcome;
        buyer_state[c] = DONE;
        buyer_done[c] = true;
        /* These local message fields will never be used again. */
        kind = 0;
        outcome = 0;
        b = 0;
        s = 0
    }
}

proctype BookingService()
{
    mtype kind;
    byte c, b, p, s;

end_wait_request:
    do
    :: atomic {
        inbox?kind, c, b, p;
        if
        :: kind == RESERVE ->
            /* Find the first free seat. */
            s = 0;
            do
            :: s < N_SEATS ->
                if
                :: seat_state[s] == FREE -> break
                :: else -> s++
                fi
            :: else -> break
            od;
            if
            :: s < N_SEATS ->
                b = c + 1;
                booking_owner[b] = c;
                booking_seat[b] = s;
                booking_state[b] = ACTIVE;
                created[b] = true;
                booking_active[b] = true;
                seat_state[s] = HELD;
                seat_booking[s] = b;
                seat_free[s] = 0;
                active_count[s]++;
                replies[c]!RESERVED, b, s, 0;
                deadlines[c]!START_TIMER
            :: else -> replies[c]!RESULT, 0, 0, NO_SEAT
            fi
        :: kind == PAY ->
            if
            :: booking_active[b] && booking_owner[b] == c &&
               payment_state[b] == NOT_STARTED ->
                payment[b] = p;
                payment_state[b] = PENDING;
                payments[c]!CHARGE
            :: else -> skip /* The reservation has already ended. */
            fi
        :: kind == CANCEL || kind == EXPIRE ->
            if
            :: booking_active[b] && booking_owner[b] == c ->
                if
                :: kind == CANCEL -> booking_state[b] = CANCELLED
                :: kind == EXPIRE -> booking_state[b] = EXPIRED
                fi;
                s = booking_seat[b];
                booking_active[b] = false;
                closed_without_ticket[b] = true;
                active_count[s]--;
                seat_state[s] = FREE;
                seat_booking[s] = 0;
                seat_free[s] = 1;
                if
                :: payment_state[b] == NOT_STARTED ->
                    replies[c]!RESULT, b, s, booking_state[b]
                :: else -> skip /* Resolve the pending payment first. */
                fi
            :: else -> skip
            fi
        :: kind == PAY_OK ->
            if
            :: payment_state[b] == PENDING && payment[b] == p ->
                s = booking_seat[b];
                if
                :: booking_active[b] && seat_booking[s] == b ->
                    booking_active[b] = false;
                    booking_state[b] = BOUGHT;
                    payment_state[b] = PAID;
                    active_count[s]--;
                    ticket_count[s]++;
                    seat_state[s] = SOLD;
                    issued[b] = true;
                    ticket_for_payment[p] = true;
                    replies[c]!RESULT, b, s, TICKET
                :: closed_without_ticket[b] ->
                    payment_state[b] = REFUND_PENDING;
                    payments[c]!REFUND
                fi
            :: else -> skip
            fi
        :: kind == PAY_FAIL ->
            if
            :: payment_state[b] == PENDING && payment[b] == p ->
                payment_state[b] = FAILED;
                s = booking_seat[b];
                if
                :: booking_active[b] ->
                    booking_state[b] = PAYMENT_FAILED;
                    booking_active[b] = false;
                    active_count[s]--;
                    seat_state[s] = FREE;
                    seat_booking[s] = 0;
                    seat_free[s] = 1
                :: else -> skip
                fi;
                replies[c]!RESULT, b, s, booking_state[b]
            :: else -> skip
            fi
        :: kind == REFUND_OK ->
            if
            :: payment_state[b] == REFUND_PENDING && payment[b] == p ->
                payment_state[b] = REFUNDED;
                replies[c]!RESULT, b, booking_seat[b], REFUNDED
            :: else -> skip
            fi
        fi;
        /* The next receive replaces these request-local values. */
        kind = 0;
        c = 0;
        b = 0;
        p = 0;
        s = 0
    }
    od
}

proctype PaymentService(byte c)
{
    byte p = c + 1;

end_ready:
    payments[c]?CHARGE;
    worker_state[c] = PROCESSING;
    if
    :: atomic {
           charged[p] = true;
           worker_state[c] = CHARGED
       };
       atomic {
           inbox!PAY_OK, c, p, p;
           worker_state[c] = PAID
       };
end_wait_refund:
       payments[c]?REFUND;
       worker_state[c] = REFUNDING;
       atomic {
           returned[p] = true;
           worker_state[c] = REFUNDED
       };
       inbox!REFUND_OK, c, p, p
    :: worker_state[c] = DECLINED;
       atomic {
           inbox!PAY_FAIL, c, p, p;
           worker_state[c] = FAILED
       }
    fi
}

proctype Deadline(byte c)
{
end_ready:
    deadlines[c]?START_TIMER;
    inbox!EXPIRE, c, c + 1, 0
}

init
{
    byte c;
    atomic {
        /* Each claim uses a seat OR a buyer, so paired choices suffice. */
        c = 0;
        do
        :: break
        :: c < N_SEATS - 1 || c < N_BUYERS - 1 -> c++
        od;
        check_seat = c % N_SEATS;
        check_buyer = c % N_BUYERS;
        check_booking = check_buyer + 1;
        check_payment = check_buyer + 1;

        run BookingService();
        c = 0;
        do
        :: c < N_BUYERS ->
            run Buyer(c);
            run PaymentService(c);
            run Deadline(c);
            c++
        :: else -> break
        od
    }
}

/* Safety: the selected seat, reservation and payment. */
ltl S1 { [] (ticket_count[check_seat] <= 1) }
ltl S2 { [] (active_count[check_seat] + ticket_count[check_seat] <= 1) }
ltl S3 { [] (seat_free[check_seat] + active_count[check_seat] + ticket_count[check_seat] == 1) }
ltl S4 { [] (issued[check_booking] -> charged[payment[check_booking]]) }
ltl S5 { [] (returned[check_payment] -> charged[check_payment]) }
ltl S6 { [] !(issued[check_booking] && returned[payment[check_booking]]) }

/* Liveness: the selected buyer, reservation and payment. */
ltl L1 { [] (requested[check_buyer] -> <> buyer_done[check_buyer]) }
ltl L2 { [] (charged[check_payment] -> <> (ticket_for_payment[check_payment] || returned[check_payment])) }
ltl L3 { [] (created[check_booking] -> <> !booking_active[check_booking]) }
ltl L4 { [] ((closed_without_ticket[check_booking] && charged[payment[check_booking]]) -> <> returned[payment[check_booking]]) }
