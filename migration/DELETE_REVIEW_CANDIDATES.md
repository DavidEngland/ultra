# Delete Review Candidates (from parent ABL workspace)

Purpose: track likely clutter or superseded files for human review later. This list does not delete anything.

## In this new repo: likely cleanup candidates

- src/julia/preprocess_tower_to_ultra_input.bak.jl (backup copy)
- src/julia/preprocess_tower_to_ultra_input.v1.jl (legacy version snapshot)
- src/julia/# toy_sc_m.jl (odd filename, likely accidental)
- src/julia/Dick,.md (oddly named scratch-like file)
- src/julia/toy_sc_m.jl (legacy toy model, optional archive)

## Safe candidates (likely remove)

- julia/preprocess_tower_to_ultra_input.bak.jl (backup file)
- julia/preprocess_tower_to_ultra_input.v1.jl (legacy version snapshot)
- julia/Dick,.md (oddly named scratch-like file)
- Untitled-1.md and other Untitled-*.md files
- Search entire ABL directory.md
- That's an important notational clarifica
- emails.md and email_to_dick_arastoo.txt
- *.vcf contact card files

## Possible duplicates or superseded drafts (review manually)

- Curvature and Discretization in MOST Closures.md
- Curvature and Discretization in MOST-Based Closures.md
- Curvature and Discretization in MOST Closures.md (already modified above) – no extra changes.
- Dynamic Critical Richardson Number.md
- Dynamic_Ric_Hybrid_MOST_Ri_Draft.md
- draft JAMC Grid Depends.md
- new draft.md
- draft critique.md

## Archive-only candidates (not needed in new focused repo)

- social/*
- emails/*
- broad manuscript drafts unrelated to ultraspherical workflow execution
- legacy reference code not used by current Julia pipeline

## Review checklist

1. Confirm file is not referenced by current scripts or docs.
2. Confirm no unique scientific content is lost.
3. If uncertain, move to archive folder before deletion.
