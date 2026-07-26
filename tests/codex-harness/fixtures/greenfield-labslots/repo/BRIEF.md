# LabSlots — teaching lab booking for the Physics department

We run six teaching labs. Right now bookings happen in a shared spreadsheet and
it goes wrong constantly: two groups turn up for the same bench, someone
cancels and nobody downstream ever hears about it, and at the end of term we
have no idea which labs were actually used.

Build us something better.

## Who uses it

- **Students** book a bench for a lab session, see their own bookings, and
  cancel one.
- **Lab technicians** open and close sessions, and see who is booked.
- **The department admin** wants utilisation numbers at the end of term.

Everyone signs in. A student must never be able to see or cancel another
student's booking.

## How booking works

Each lab has a fixed number of benches. A **session** is one lab on one date
for a fixed two-hour window — for example, Optics Lab, 14 March, 09:00–11:00.
A technician creates sessions; students book a bench in one.

The rules that matter to us, in the order we argue about them:

1. **A session cannot be overbooked.** If the Optics Lab has 12 benches, the
   13th student to try must not get one. This is the rule that breaks today
   and it is the reason we are paying for this.

2. **When a session is full, students join a waitlist.** Waitlist position is
   the order they joined. If somebody cancels, the person at the front of the
   waitlist gets the freed bench automatically and is told. If two people
   cancel, the first two on the waitlist get in, in order.

3. **A student cannot be in two places at once.** Two sessions that overlap in
   time on the same date — booking the second must be refused, and the message
   must say which existing booking it clashes with. Sessions that merely touch
   (one ends 11:00, the next starts 11:00) do not overlap.

4. **Cancellation has a cut-off.** A student may cancel up to 24 hours before
   the session starts. After that the booking is locked and only a technician
   can release it.

5. **A closed session takes no bookings.** A technician can close a session
   early; existing bookings survive, new ones are refused, and the waitlist
   stops promoting.

## Utilisation

The admin needs one page: for a date range, per lab — sessions held, benches
available, benches booked, and the percentage used. Cancelled bookings do not
count as used. We will export this to a spreadsheet at some point but a page on
screen is enough for now.

## Things we do not need

No email or SMS — an in-app notification the student sees when they next open
the site is fine. No payments. No mobile app. No calendar integration, though
please do not make it impossible later.

## Scale

About 400 students, six labs, maybe 40 sessions a week. It does not need to be
fast, it needs to be correct.
