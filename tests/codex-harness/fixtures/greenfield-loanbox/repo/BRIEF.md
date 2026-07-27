# LoanBox — equipment loans for the Physics stores counter

The stores counter lends small equipment to students: multimeters, clamp
stands, stopwatches. Right now it is a paper ledger and we lose things.

We want a small web app, nothing clever.

## Who uses it

- **Students** sign in, see what they currently have on loan, and see when each
  item is due back.
- **Stores staff** sign in, look up an item, and record a loan out or a return.

## What it must do

1. **An item can only be on loan to one person at a time.** If staff try to
   lend out an item that is already out, refuse it and say who has it.
2. **A loan is due back 7 days after it goes out.** Staff record the return,
   which frees the item.
3. **Overdue list.** Staff need one page listing every loan past its due date,
   oldest first, with the student's name and the item.
4. **A student sees only their own loans.** Never anyone else's.

## What we do not need

No email, no fines, no barcode scanning, no reservations or queueing. Staff
type the item name. Sign-in can be plain username and password.

## Scale

About 200 students, maybe 80 items, a handful of loans a day. Correctness over
cleverness — the one thing that must never happen is the same item recorded as
on loan to two people.
