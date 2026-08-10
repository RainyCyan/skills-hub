# Test Quality Gates

Load this reference before writing or changing a test, mock, fake, fixture,
snapshot, or test-only helper.

## Gate 1: Name The Break

Before writing the test body, state one realistic production mutation that
must make the test fail.

Acceptable mutations include:

- wrong branch or boundary condition;
- missing state change or side effect;
- wrong argument, result, status, or emitted event;
- empty/default return replacing a real result;
- missing validation for empty, zero, nil, unauthorized, malformed, or
  out-of-range input;
- one extra or missing retry, query, write, or message when count is part of
  the contract.

Reject the test when:

- only source text, a private symbol, or a constant declaration can make it
  fail;
- it tests framework behavior rather than the repository's boundary contract;
- the test and implementation can be wrong in the same way and still agree;
- it exists only to increase coverage.

## Gate 2: Derive Expectations Independently

- Use requirement literals, hand-calculated examples, protocol fixtures, or
  independently maintained golden data.
- Never call production builders, normalizers, serializers, or algorithms to
  construct the expected value for those same functions.
- Prefer table-driven cases with literal expected values when several
  boundaries share one rule.
- Treat snapshot creation as an assertion-writing action. Review every changed
  field; never accept a snapshot only because the command offers an update
  flag.

## Gate 3: Test A Stable Seam

Choose the narrowest public seam that can prove the behavior:

| Behavior | Preferred seam |
|----------|----------------|
| Pure transformation or policy | Public function/module API |
| Database, filesystem, queue, cache, or service boundary | Integration test using the real local boundary or a faithful fake |
| HTTP/RPC behavior | Registered endpoint/client contract with request and response evidence |
| UI behavior | User-observable role/text/state and the real component tree |
| Critical cross-system flow | Narrow end-to-end test |

Never test private methods directly to avoid setup. Difficult setup is evidence
that the public interface or dependency boundary may need simplification.

## Gate 4: Earn Every Test Double

Use this preference order:

1. real implementation;
2. faithful fake;
3. specific stub;
4. interaction mock.

Before replacing a real dependency:

1. List the real operation's side effects.
2. Keep every side effect the behavior under test depends on.
3. Replace only the slow, external, non-deterministic, or destructive level.
4. Make fake/stub responses match the complete real structure used at the
   boundary, including documented required fields.

Reject a mock when:

- the assertion only proves that the mock was called or rendered, while the
  consumer-visible result is untested;
- mock setup exceeds the behavioral setup and obscures the scenario;
- the mocked method also performs state changes needed by the real behavior;
- the mock accepts every input and therefore cannot distinguish branches.

Call counts, ordering, and arguments are valid assertions only when they are
the external contract, such as retry limits, idempotent writes, or protocol
ordering.

## Gate 5: Keep Tests Deterministic And Local

- Control clocks and time zones.
- Seed or replace randomness.
- Isolate filesystem paths, ports, databases, queues, caches, environment
  variables, and process-global state.
- Await asynchronous work; never use arbitrary sleep as synchronization.
- Restore mutated global state in test teardown.
- Make each test create and clean up its own state.
- Verify a new test passes alone and in its related suite.

When a test is flaky, fix the uncontrolled dependency or synchronization
boundary. Never hide flakiness with retries unless retry behavior itself is
the subject of the test.

## Gate 6: Keep Test Code Honest

- One test may contain multiple assertions when they prove one observable
  concept. Split tests when failure messages would refer to independent
  behaviors.
- Prefer descriptive, local setup over abstraction that forces readers to
  chase helpers. Remove duplication only when the shared helper preserves the
  scenario's meaning.
- Put factories, cleanup, and test-only controls in test utilities.
- Add a production method only when production owns and uses that capability;
  never add it solely to make teardown convenient.
- Do not test constructors, getters, constants, or forwarding methods unless
  they validate, normalize, default, derive, enforce, or trigger a
  consumer-visible side effect.

## Mutation Check

Before completion, mentally or mechanically apply realistic mutations to each
new behavior:

| Mutation | Required signal |
|----------|-----------------|
| Invert the new condition | At least one named test fails |
| Remove the state change or side effect | At least one named test fails |
| Return empty/default data | At least one named test fails |
| Use the adjacent boundary value | A boundary test distinguishes it |
| Skip validation or authorization | A negative test fails |
| Add or remove one retry/query/write | A contract test fails when count matters |

If no test catches a realistic mutation, add the smallest behavioral case
that does. If the mutation is an intentional design choice rather than a bug,
do not add a change-detector test for it.

## Stop Conditions

Stop and repair the test before production work when any is true:

- the test passes before the behavior is implemented;
- RED is an import, syntax, fixture, environment, timeout, or setup error;
- expected and actual values come from the same logic;
- the assertion observes only a mock or private implementation detail;
- the test fails under a harmless refactor with unchanged public behavior;
- the test depends on order, residue, wall-clock timing, or an external
  service not controlled by the test.
