---
name: review-scientific-fortran
description: >-
  Review scientific FORTRAN code (e.g. the ICON model) for numerical
  correctness, modern Fortran standards, performance/portability, and project
  conventions. Use this skill when asked to review, audit, or critique Fortran
  source (.f90/.F90/.inc/.incf) in a scientific computing or climate/weather
  modeling context.
---

# Reviewing Scientific FORTRAN Code

This skill describes how to perform a high-signal review of scientific FORTRAN
code. It combines general modern-Fortran best practices with the specific
conventions used in this repository (the ICON modeling framework). Focus on
issues that genuinely matter — numerical correctness, bugs, portability, and
maintainability — and avoid nitpicking style that the automated formatters
already enforce.

## How to use this skill

1. Identify the changed or target Fortran files (`.f90`, `.F90`, `.inc`,
   `.incf`).
2. Read the surrounding module to understand precision, data flow, and the
   physical/numerical intent before judging a line.
3. Review against the checklists below, in priority order: **correctness first**,
   then **standards/portability**, then **performance**, then **style**.
4. Report only issues that matter, with file/line references and a concrete
   suggested fix. Distinguish bugs from suggestions.

## Project conventions (ICON-specific)

Check that contributions follow the established repository conventions:

- **License header**: every source file must start with the ICON header block
  and the correct SPDX identifier (`! SPDX-License-Identifier: BSD-3-Clause`).
  See existing modules such as `src/shared/mo_compare_float.f90` for the exact
  block. New files must be REUSE-compliant.
- **Precision kinds**: never hard-code `REAL*8`, `DOUBLE PRECISION`, or literal
  kind numbers. Use the named kind parameters from `mo_kind`
  (`wp` working precision, `dp`, `sp`, `vp`, `i4`, `i8`, …) and tag real
  literals with the kind (e.g. `1.0_wp`, not `1.0` or `1.0d0`).
- **`IMPLICIT NONE`**: required in every module, subroutine, and function.
- **Encapsulation**: modules should declare `PRIVATE` by default and explicitly
  `PUBLIC` only what is part of the interface. No `COMMON` blocks or `EQUIVALENCE`.
- **`INTENT`**: every dummy argument must have an explicit `INTENT(IN/OUT/INOUT)`.
  Use `OPTIONAL` with `PRESENT()` checks rather than sentinel values where it
  improves clarity.
- **Formatting**: the repo enforces formatting via pre-commit hooks
  (`codee-format`/`.codee-format`, `fprettify`-style rules: 2-space indent,
  132-column limit, uppercase keywords, `::` separators). Do not flag whitespace
  or casing the formatter already normalizes — flag only logic.
- **OpenACC/OpenMP**: GPU and threading directives use the ICON wrappers
  (`!$ACC`, `ICON_OMP_*`). When reviewing kernels, check that data clauses
  (`PRESENT`, `COPYIN`, `CREATE`) are correct, that loop-carried dependencies
  are absent, and that the directives are kept in sync with the underlying
  computation. The `icon-openacc-beautifier` hook handles their formatting.
- **Tests**: numerical/unit changes should come with or update tests under
  `test/unit-tests/` (pFUnit-style). Cross-check that new behavior is covered.

## Numerical correctness (highest priority)

- **No floating-point equality**: flag `a == b` / `a /= b` on reals. Use a
  tolerance-based comparison (see `notEqual` in `mo_compare_float`), with both
  relative and absolute tolerances.
- **Cancellation, overflow, underflow**: watch for subtracting nearly equal
  numbers, summing many terms naively (prefer numerically stable / compensated
  summation), dividing by potentially tiny denominators, and `EXP`/`LOG` of
  unbounded arguments. Suggest guards or reformulation.
- **Mixed-precision pitfalls**: integer division used where real division is
  intended (`1/2` → `0`), implicit promotion that silently loses precision, and
  untagged literals defaulting to the wrong kind.
- **Initialization**: every variable must be initialized before use; never rely
  on compiler zero-init or `SAVE`-by-accident (a variable initialized in its
  declaration implicitly gets `SAVE` — verify that is intended).
- **Constants and units**: physical/algorithmic constants belong in a shared
  constants module, documented with units and source. Flag magic numbers.
- **Array conformance & bounds**: check shape/extent agreement, off-by-one in
  loops, correct halo/boundary handling, and that `SIZE`/`LBOUND`/`UBOUND` are
  used rather than hard-coded extents.
- **Determinism/reproducibility**: be wary of reductions whose result depends on
  thread count or order when bit-reproducibility is required.

## Modern Fortran standards & safety

- Prefer `MODULE`s with explicit interfaces over external procedures and
  `INCLUDE`. Avoid obsolescent features: arithmetic `IF`, computed/assigned
  `GOTO`, `COMMON`, `EQUIVALENCE`, fixed-form constructs, statement functions.
- Prefer `ALLOCATABLE` over `POINTER` unless pointer semantics are required;
  ensure every `ALLOCATE` has a matching `DEALLOCATE` (or is automatically
  deallocated) and that `ALLOCATE`/`DEALLOCATE` `stat=` is checked where failure
  is plausible.
- Use intrinsic modules (`ISO_FORTRAN_ENV`, `IEEE_ARITHMETIC`, `ISO_C_BINDING`)
  appropriately; use `IEEE_IS_NAN` rather than ad-hoc NaN tricks.
- Use derived types and `ASSOCIATE` to clarify intent; avoid deep argument lists
  where a derived type is clearer.
- Error handling should be explicit (status codes / `finish`-style aborts used in
  the codebase), not silent.

## Performance & portability

- Respect Fortran column-major memory order: innermost loop over the first
  (fastest-varying) array dimension; flag cache-unfriendly access patterns.
- Avoid creating large automatic/temporary arrays on the stack and unnecessary
  array temporaries from non-contiguous slices passed to procedures.
- Keep code portable across the compilers ICON targets; avoid compiler-specific
  extensions and assumptions about evaluation order or `KIND` values.
- Ensure OpenACC/OpenMP regions do not introduce data races and that host/device
  data stays consistent.

## Documentation & maintainability

- Public procedures and modules should have a short description of purpose,
  arguments (with units), assumptions, and references to papers/equations.
- Names should be descriptive (indices like `i,j,k` are fine); explain
  non-obvious algorithms and any numerical tolerances.
- Comments should explain *why*, not restate the code.

## Review output

For each finding, provide:

- **Severity**: bug / correctness risk / standards / performance / nit.
- **Location**: file and line(s).
- **Explanation**: what is wrong and why it matters.
- **Suggested fix**: concrete, minimal, and consistent with repo conventions.

Prioritize a small number of important findings over an exhaustive list of minor
ones. If the change is numerically subtle, recommend a regression/unit test
rather than only a code edit.

## References

- Repository conventions: `.codee-format`, `.pre-commit-config.yaml`,
  `CONTRIBUTING.md`, `src/shared/mo_kind.f90`, `src/shared/mo_compare_float.f90`.
- ICON Contribution Guidelines: https://docs.icon-model.org/contribute/guidelines/contribution_guidelines.html
- *Modern Fortran Explained* (Metcalf, Reid, Cohen).
- Fortran-lang best practices: https://fortran-lang.org/learn/best_practices/
- pFUnit testing framework: https://github.com/Goddard-Fortran-Ecosystem/pFUnit
