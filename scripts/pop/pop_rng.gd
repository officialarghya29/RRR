class_name PopRng
extends RefCounted
## Deterministic generator for the Pop sim core (plan A2.2).
##
## Q1 was answered on 2026-10-06 (review.md, D5): measured constants with
## citation are acceptable in tracked files, so this is now the reference
## generator itself — a 32-bit LCG seeded from time once, drawing the high 16
## bits of the state:
##   SDLPoP src/seg009.c:251-252 (`random_seed*214013+2531011`,
##   `(random_seed>>16) % (max+1)`), one-time seeding seg009.c:246-250.
## Generator *identity* (vs. our earlier placeholder) is proven by plan §8
## gate 3 once the duel transcript exists; the determinism gate only proves
## seed → reproducible state, which either generator satisfies.
## Cross-reference: docs/PARITY.md §14.

const MULTIPLIER: int = 214013        ## reference LCG increment factor (seg009.c:251)
const INCREMENT: int = 2531011        ## reference LCG addend (seg009.c:251)
const WORD_MASK: int = 0xFFFFFFFF      ## keep the state in 32 bits, like a dword

var state: int = 1


static func normalize_seed(seed: int) -> int:
	return seed & WORD_MASK


## Advance the generator once and return the new 32-bit state.
func next_u32() -> int:
	# int64 multiply of two <2^32 values cannot overflow int64; mask after add.
	state = (state * MULTIPLIER + INCREMENT) & WORD_MASK
	return state


## Uniform-ish integer in 0..n-1 (n > 0). Equals SDLPoP's `prandom(n-1)`,
## which returns 0..max inclusive from the high 16 bits (seg009.c:252).
## Demand-driven consumption will replace the sim skeleton's per-tick advance
## once guard AI exists (TODO A2.2).
func rand_below(n: int) -> int:
	if n <= 0:
		return 0
	next_u32()
	return (state >> 16) % n


## One step of the generator as a pure function of a state integer, for use
## inside PopSim.step without instantiating objects.
static func step_state(seed: int) -> int:
	return (seed * MULTIPLIER + INCREMENT) & WORD_MASK
