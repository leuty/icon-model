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
- **`INTENT`**: every dummy argument must have an explicit `INTENT(IN/OUT/INOUT)`,
  and is conventionally documented with a trailing `!<` comment that includes
  units (e.g. `REAL(wp), INTENT(IN) :: dt !< integration time-step [s]`). Use
  `OPTIONAL` with `PRESENT()` checks rather than sentinel values.
- **`USE ... ONLY`**: imports are always restricted with `ONLY:` and list only
  the symbols actually used (e.g. `USE mo_kind, ONLY: wp`). Flag wildcard `USE`
  without `ONLY`.
- **Documentation comments**: modules and public procedures begin with a `!>`
  doc comment; declarations use trailing `!<` comments. This drives the
  generated API docs — keep them accurate.
- **Formatting**: the repo enforces formatting via pre-commit hooks
  (`codee-format`/`.codee-format`, `fprettify`-style rules: 2-space indent,
  132-column limit, uppercase keywords, `::` always added, `EndStructureAndName`
  end statements). Do not flag whitespace or casing the formatter already
  normalizes — flag only logic.
- **Tests**: numerical/unit changes should come with or update tests under
  `test/unit-tests/`. Tests are exit-code based via `mo_test_common`
  (`test_pass` → exit 0, `test_skip` → exit 77, `test_fail` → exit 2) and are
  MPI-aware. Cross-check that new behavior is covered.

## Distilled ICON idioms (verify these are followed)

These are the concrete, recurring patterns in the codebase; deviations are worth
flagging.

- **Error handling — `finish`**: abort via `USE mo_exception, ONLY: finish` and
  `CALL finish(routine_name, message)`, where `routine_name` matches the
  enclosing procedure. This is MPI-aware (prints rank, aborts all ranks). Do not
  use bare `STOP`, `ERROR STOP`, or `WRITE(*,*)`-then-continue for fatal errors.
  Informational/warning output goes through `mo_exception` (`message`/`warning`),
  not raw `PRINT`/`WRITE(*,*)`.
- **Float comparison — `notEqual`**: compare reals via
  `USE mo_compare_float, ONLY: notEqual` (relative + absolute tolerance), never
  `==`/`/=` on `REAL`.
- **`nproma` blocking**: array fields are dimensioned `(nproma, nlev, nblks)`
  with `USE mo_parallel_config, ONLY: nproma`. The canonical loop nest is:
  outer block loop `jb = 1, nblks_c` (handling the partial last block via
  `npromz_c`/`nlen`), vertical loop `jk = 1, nlev`, inner column loop
  `jc = 1, nlen`. The innermost loop must run over the first (column) dimension
  for cache-friendly, column-major access. Flag loop nests that violate this
  ordering.
- **Index naming**: `jb` = block index, `jc` = cell/column index, `jk` = vertical
  level index, `jg` = domain/grid index. Prefixes `n*` are counts/sizes, `i*` are
  generic integers. Follow these so blocking code stays readable.
- **OpenMP via macros**: threading uses the `ICON_OMP_*` macros from
  `#include "omp_definitions.inc"` and `ICON_OMP_DEFAULT_SCHEDULE`. When
  reviewing parallel regions, verify `PRIVATE`/`SHARED` clauses list every
  thread-local (especially per-block temporaries) and that there are no
  loop-carried dependencies or races across blocks.
- **OpenACC**: GPU kernels use `!$ACC` directives gated by an `lzacc`/`lacc`
  logical and `#ifdef _OPENACC`. Check that data clauses (`PRESENT`, `COPYIN`,
  `CREATE`, `ASYNC`) are correct and host/device data stays consistent; the
  `icon-openacc-beautifier` hook handles their formatting.

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
- Names should follow the ICON index conventions (`jb`/`jc`/`jk`/`jg`); explain
  non-obvious algorithms and any numerical tolerances.
- Comments should explain *why*, not restate the code. Use `!>` for procedure/module
  headers and `!<` for inline declaration docs, as the rest of the codebase does.

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
  `CONTRIBUTING.md`, `src/shared/mo_kind.f90`, `src/shared/mo_compare_float.f90`,
  `src/include/omp_definitions.inc`,
  `test/unit-tests/common/mo_test_common.f90`. The `mo_exception` module
  (`USE mo_exception, ONLY: finish, message, warning`) provides the standard
  abort/logging routines.
- Idiom examples: `src/atm_dyn_iconam/mo_hydro_adjust.f90` (nproma blocking,
  OpenMP), `src/lnd_phy_schemes/sfc_terra_transport.f90` (INTENT, `finish`).
- ICON Contribution Guidelines: https://docs.icon-model.org/contribute/guidelines/contribution_guidelines.html
- *Modern Fortran Explained* (Metcalf, Reid, Cohen).
- Fortran-lang best practices: https://fortran-lang.org/learn/best_practices/
- pFUnit testing framework: https://github.com/Goddard-Fortran-Ecosystem/pFUnit
