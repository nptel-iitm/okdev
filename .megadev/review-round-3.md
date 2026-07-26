## Code Review — Round 3 Escalation

### Status: CHANGES REQUESTED

Reviewed immutable head: `4a3bacda3cbd0670854fa9a270acb4dbaebb4c87`

The normative orchestration documents are broadly consistent, syntax/ShellCheck/full committed tests pass, and the earlier disconnected-fixture, candidate-tree, and landing-race findings are materially improved. Adversarial mutation testing nevertheless found five remaining MUST FIX gaps:

1. **Git replacement objects can spoof candidate identity.** Identity-sensitive Git commands honor `refs/replace`, allowing an unsafe raw object ID to appear to have the valid candidate's lineage/tree during validation and checkout. Run identity, construction, checkout, and install operations with replacement semantics disabled (for example `GIT_NO_REPLACE_OBJECTS=1`) and add a negative replacement-object regression.
2. **Ordered target/source parents are not mutation-protected.** Add wrong-order, missing-parent, or extra-parent candidates using the correct combined tree and prove rejection before testing, installation, or delivery. Make ordered target-first/source-second lineage explicit in the normative identity contract.
3. **Atomicity is not mutation-protected.** Add a deterministic interleaving that distinguishes the current one-transaction source verification + target CAS from a vulnerable source-check-then-target-update implementation.
4. **Test evidence is not attested by the checkout.** Have the isolated runner attest its raw resolved `HEAD`; bind the outcome and receipt to that SHA and reject evidence when it differs from `tested_candidate_sha`.
5. **Exact-result backstop is not mutation-protected.** Advance the target at the check-to-execution boundary, attest the backstop checkout's raw `HEAD`, and require it to equal the immutable merge result so following a moving target ref fails.

Validation performed by the fresh reviewer:

- `bash -n tests/test-merge-result-gate.sh` — pass
- Dockerized ShellCheck 0.10.0 — pass
- `./tests/test-merge-result-gate.sh all` — pass
- Existing requested mutation suite — 10/10 killed
- Additional discrimination mutations — 4 survived (ordered-parent removal, split atomic transaction, wrong candidate test commit, moving target backstop)
- Scope, secrets, executable mode, commit trailers, and documentation consistency — pass

This is the third review round with MUST FIX findings still open. Per the repository's convergence rule, implementation is stopped and escalated to the user/tech lead. No fourth repair round is authorized by this comment. The PR remains open and must not be merged.
