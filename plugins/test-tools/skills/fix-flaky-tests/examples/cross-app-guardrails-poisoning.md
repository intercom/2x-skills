# RateLimitGuard Poisoning (synthetic example)

**Reported**: `spec/services/rate_limit_guard_spec.rb` failing intermittently in CI.

**Validated**: CI log search on the failing job showed the exception + backtrace, matching a few recent default-branch builds.

**Co-residency evidence**: the failing shard ran at seed 34567 and its spec list — read off the CI log — put `order_export_spec.rb` in the same shard as the victim. That made it a candidate, not a proven poisoner; the log carries no per-example execution order. Reading its `around` hook is what closed the mechanism.

**Classified**: Global state poisoning — seed-dependent, passes in isolation.

**Root cause**: `RateLimitGuard` (`app/services/rate_limit_guard.rb`) tracks its on/off state in a module-level instance variable (`@enabled`), toggled via `RateLimitGuard.disable!` / `RateLimitGuard.enable!`. Two unrelated specs, `order_export_spec.rb` and `team_permissions_spec.rb`, had `around` hooks that called `RateLimitGuard.disable!` and then, in an `ensure` block meant to restore the default, mistakenly called `disable!` again instead of `enable!` — leaving `@enabled = false` for every test that ran afterward in the same process.

**Fix**: Changed the `ensure` blocks in both specs to call `RateLimitGuard.enable!` (the initializer default). Hardened the victim spec with an explicit `RateLimitGuard.enable!` in a `before` block as defense-in-depth.

**Sweep**: Grepped the suite for the same pattern (`grep -rn 'RateLimitGuard.disable!' spec/`) and found `webhook_delivery_spec.rb`'s `clean_up` helper had the identical bug — fixed that too.

**Guidance updated**: Added a "Module-Level Instance Variables" row to `references/classification-generic.md`'s global-state-poisoning entry, and noted the `around`/`ensure` restore-to-wrong-value gotcha as a pattern to grep for on future poisoning investigations.
