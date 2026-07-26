# Requirements Document
## Project: Roster

### 1. Overview
A shift-rostering tool for three cafes. Managers build and publish weekly
rosters; staff view their shifts and request swaps, which managers approve.

### 2. Functional Requirements
1. As a manager, I can create a weekly roster for one cafe and assign staff to shifts.
2. As a manager, I can publish a roster, after which staff can see it.
3. As a staff member, I can see my own published shifts on a phone.
4. As a staff member, I can request to swap one of my shifts with a named colleague.
5. As a manager, I can approve or decline a swap request; approval reassigns the shift.
6. As an administrator, I can create users and grant per-cafe manager permissions.

### 3. Non-Functional Requirements
1. Roster views render within 500ms at p95 for a 3-cafe, 40-staff, 1-week dataset.
2. Sign-in is via the organisation's Google Workspace domain only.
3. The staff-facing views are usable at 375px width.

### 4. Technical Constraints
1. Google Workspace SSO is required.
2. No tech stack was specified by the customer.

### 5. UI/UX Requirements
Pages: sign-in, manager roster editor, roster publish confirmation, staff shift
list, swap request form, manager swap queue.

### 6. Testing Requirements
Not specified.

### 7. Ambiguities
1. Overlapping-shift prevention: default is to reject direct overlaps only.
2. Recipient consent for swaps: default is manager approval is authoritative.

### 8. Assumptions
1. Week runs Monday to Sunday.
2. One organisation time zone.
