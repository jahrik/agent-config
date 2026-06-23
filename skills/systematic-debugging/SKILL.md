---
name: systematic-debugging
description: A disciplined root-cause debugging method — reproduce, isolate, hypothesize, change one thing at a time, and fix the cause not the symptom. Use when chasing a bug, test failure, or unexpected behaviour.
---

# Systematic Debugging

Debug by method, not by guessing. The goal is to _understand_ the failure before changing code.

## 1. Reproduce

Get a reliable, minimal repro. If it's intermittent, find what makes it consistent (input,
timing, environment). A bug you can't reproduce, you can't confirm you've fixed.

## 2. Read the actual error

Read the full message, stack trace, and logs — both the top frame and the root cause. Don't skim.
The answer is in the output more often than not.

## 3. Isolate

Narrow the surface: which commit (`git bisect`), which input, which layer, which line. Remove
variables until the failure is cornered, shrinking the repro as you go.

## 4. Form one hypothesis

State what you think is wrong and what you'd expect to see if you're right. Then **change one
thing** and check the prediction. Resist shotgun fixes — changing several things at once tells you
nothing about which one mattered.

## 5. Verify the root cause

Confirm the cause, not a correlation. You should be able to explain _why_ the bug happens and why
the fix addresses it. If a fix "works" but you can't say why, you're not done.

## 6. Fix the cause, add a regression test

Fix the underlying cause, not the symptom. Add a test that fails before the fix and passes after,
so the bug can't silently return.

## Anti-patterns

- Changing code and hoping, with no hypothesis.
- "Fixing" with a retry / sleep / broad try-except that hides the failure.
- Calling a failure "flaky" or "transient" without evidence.
- Editing the test to pass instead of fixing the code.
