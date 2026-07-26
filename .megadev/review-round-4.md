## Code Review — Exceptional Round 4 Escalation

### Status: CHANGES REQUESTED

Reviewed immutable head: `73b9073ea0b375a5d351d0fc721ab33edafd371d`

The direct exact-candidate path is materially stronger: replacement-object spoofing is disabled, exact raw tree and ordered-lineage checks exist, runner attestation is bound to candidate/result identities, the exact-install path uses one ref transaction, and the immutable-result backstop blocks delivery on red. Baseline syntax, Dockerized ShellCheck, semantic, consistency, and full tests pass.

Fresh adversarial review nevertheless found the following MUST FIX findings:

1. **Queue base does not prove it contains the current target.** An unrelated current queue base can produce internally consistent evidence and a passing candidate while dropping target-only state. Require replacement-disabled target-to-queue-base ancestry on the defined cumulative first-parent chain and add an unrelated-base rejection test.
2. **The queue transaction may guard the wrong snapshot ref.** Validation uses the supplied `queue_snapshot_ref`, but the atomic transaction hardcodes `refs/megadev-queue/snapshot`. Guard the exact validated ref and add a non-default-ref race regression.
3. **Queue consumption does not actually land and backstop the queue-produced candidate.** Atomically transition the target to exact tested cumulative `C`, guard source/target/base/snapshot, retain immutable platform receipt evidence in that operation, capture the raw result from the queue operation, and run the replacement-disabled runner-attested post-merge suite on that result. Do not satisfy queue coverage by later using the separate exact-install path.
4. **Raw-SHA evidence accepts symbolic refs/revision expressions.** Independently resolve each candidate/tested/attested identity with replacements disabled and require the submitted value itself to equal the canonical raw commit OID. Add symbolic-ref and revision-expression negatives.
5. **Critical mutation coverage remains partially self-satisfying or non-discriminating.** Add isolated behavioral mutations for each parent position, tested-candidate mismatch, stale review on otherwise valid candidate, actual split transactions under interleaving, runner self-attestation, independent platform-receipt field mismatches, exact successful consumption ref/result, disabled negative cases, and guard-removal cases. Each named mutation must emit an externally observed result artifact so removing its invocation cannot pass silently.
6. **Failed queue validation leaks temporary capture files.** Store captures beneath the fixture root covered by the EXIT trap or implement a single function cleanup epilogue.
7. **Canonical suite identity is under-modeled.** Represent the project’s canonical suite as unambiguous versioned argv/manifest evidence (including arguments and paths with spaces), bind its digest/serialization to evidence, and test reduced/mismatched commands.

Additional required queue evidence:

- target-to-queue-base chain inclusion;
- exact cumulative candidate raw SHA/tree and target-first/source-second ordered identity;
- canonical-suite PASS and runner attestation bound to exact `C`;
- immutable platform receipt for exact atomically consumed `C`;
- any predecessor, restack, generation, source, target, queue-base, snapshot, or consumed-candidate change invalidates evidence;
- all failed queue operations leave target, consumption, receipt, and delivery state unchanged.

Validation completed on this head:

- `bash -n tests/test-merge-result-gate.sh` — pass
- Dockerized ShellCheck 0.10.0 — pass
- semantic / consistency / all modes — pass
- `git diff --check` — pass
- scope, mode, obvious-secret, commit-trailer, and documentation consistency checks — pass
- multiple out-of-tree adversarial probes — exposed the findings above

The user/tech lead authorized exceptional round 4 only. Round 4 did not converge, so implementation is stopped again for explicit escalation. No fifth repair round is authorized by this comment. PR #8 remains open and must not be merged.
