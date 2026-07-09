# Thread-Local Cache in Checkout Feature Spec (synthetic example)

**Reported**: `spec/features/checkout_spec.rb` "Guest completes checkout without creating an account" failing with `expected "/orders/confirmation" to match /\/account\/orders\/.+\/receipt/`.

**Validated**: CI log search on the failing job showed 1 failure — `RSpec::Expectations::ExpectationNotMetError` at the redirect assertion. Passed after retry.

**Classified**: Thread-local cache in feature specs — non-deterministic redirect caused by a feature-flag TTL cache in the Rails server thread.

**Root cause**: The shared helper `create_guest_checkout_mocks(saved_card: false)` sets `fake_customer.email_verified = false`. After `sign_in(customer)` in `OrdersController`, `Customer#requires_email_verification?` (`app/models/customer.rb`) returns `true` because: (1) the flag `"email-verification-required"` is not globally enabled in the test database, (2) `created_at >= EMAIL_VERIFICATION_START_DATE`, and (3) `!email_verified?`. The existing stub, `allow_any_instance_of(Order).to receive(:skip_verification?)`, was on the **wrong method** — it stubs `Order#skip_verification?`, but the redirect logic actually calls `Customer#requires_email_verification?`. The flakiness mechanism: `FeatureFlag.globally_enabled?` caches its result in `Thread.current[:global_features]` with a TTL. Capybara runs the Rails server in a separate thread from the spec thread, so `FeatureFlag.clear_thread_cache` — called in the spec's own `after` hook — only clears the **spec thread's** cache. Stale cached data from a prior spec can make the flag appear enabled on the **server thread**, suppressing the verification redirect on some runs and not others.

**Fix**: Added `allow_any_instance_of(Customer).to receive(:requires_email_verification?).and_return(false)` to the `before` block in `checkout_feature_helpers.rb`. `allow_any_instance_of` is required (not a stub on a specific instance) because the Rails server thread loads its own `Customer` instance from the database — a specific-instance stub set up on the spec thread would never cross the thread boundary.

**Sweep**: `create_guest_checkout_mocks(via_social_login: false)` in the same helper has the identical `email_verified = false` pattern — the fix in the shared helper protects every checkout feature spec that uses it, not just the reported one.

**Guidance updated**: Added a "Thread-local cache in feature specs" row to the framework file's manifestation table, describing the `Thread.current`-backed cache + Capybara-separate-thread mechanism as a category to check for whenever a feature spec's redirect assertion flakes.
