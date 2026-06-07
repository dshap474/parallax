# Parallax test fixture

A deliberately tiny Python project used as a **throwaway target repo** for Parallax
smoke tests. The harness copies this directory to a fresh `mktemp` dir and `git init`s
it per run, so writer pipelines never edit this template in place.

It contains one intentional, reviewable defect: `average()` divides by `len(numbers)`
with no empty-list guard, so `average([])` raises `ZeroDivisionError`. The test file
covers the happy path only — the empty/edge case is exactly the kind of gap a Parallax
review lane should surface.
