-- Pure terminal-mode key-streak detection (#110). No vim.* calls.
--
-- A separate, much simpler state machine from patterns.lua's normal-mode
-- seq/feed and patterns_insert.lua's insert-mode iseq/feed_insert (#99's
-- precedent, applied again here): this shares no state with either and is
-- never called from the same code path, so it lives in its own sibling file
-- rather than growing an unrelated third concern onto one of them — see
-- lua/tobira/CLAUDE.md's "Module splitting policy".
--
-- logger.lua only calls feed_terminal() while its mode cache says the user
-- is in terminal-job mode (mode() == 't'), passing the canonical key name
-- '<Esc>' for the one key this cares about, or nil for anything else
-- (ordinary keys the job consumes, and the <C-\><C-n> escape sequence
-- itself — logger.lua stops routing to this module the moment mode changes
-- away from 't', so there is no need to special-case it here).
--
-- Detection: while stuck in terminal mode, a Vim user's reflex is to hit
-- <Esc> to "get back to normal mode" the way it works everywhere else in
-- Vim. Inside a terminal job, <Esc> is just forwarded to the job — nothing
-- happens from tobira's point of view, so two consecutive, uninterrupted
-- <Esc> presses (no other key or mode change in between) is a strong signal
-- the user is stuck and doesn't yet know <C-\><C-n> exits terminal mode.
--
-- False-positive guard: the threshold is 2 consecutive presses, not 1,
-- specifically because a *single* <Esc> has an ordinary purpose inside many
-- terminal jobs (cancelling a shell's in-progress reverse-search, dismissing
-- one prompt in a REPL, etc.) — that must never be flagged. Pressing <Esc>
-- *twice in a row* with nothing else in between has no such ordinary
-- purpose; it is specifically the "make sure I've left insert/whatever mode"
-- reflex vim users have, ingrained by years of it working in every other
-- mode. Any ordinary key breaks the streak back to 0, so a REPL-like job
-- that legitimately consumes one <Esc> at a time (interleaved with normal
-- typing) never trips this.
--
-- Once fired, `fired` latches until something breaks the streak (an
-- ordinary key, or logger.lua discarding this seq on a real mode change) —
-- otherwise continuing to hammer <Esc> past the 2nd press would re-fire the
-- suggestion on every subsequent press, which is exactly the spam the
-- existing float UI's cooldown/max_shown machinery already exists to avoid
-- doing at the suggestion layer. Detecting it once per streak here means
-- suggest.lua never even sees the repeat attempts.
--
-- Deliberately NOT implemented: detecting repeated <C-w> "sent straight
-- through to the job" as an alternative trigger (mentioned as a possible
-- signal in #110's design discussion). <C-w> (delete word before cursor) is
-- an extremely common, legitimate, *repeated* shell-editing action — typing
-- `<C-w><C-w>` to delete the last two words of a half-written command line
-- is completely ordinary. Counting repeated <C-w> the same way repeated
-- <Esc> is counted would false-positive constantly for routine shell use,
-- which the <Esc> signal does not suffer from (see above). #110's
-- acceptance criteria only requires the <Esc> case, so only that is
-- implemented.

local M = {}

function M.new_terminal_seq()
  return {
    esc_streak = 0,
    fired = false,
  }
end

-- How many consecutive, uninterrupted <Esc> presses in terminal-job mode
-- must be observed before suggesting <C-\><C-n>. See the false-positive
-- rationale in the module comment above for why this is 2, not 1.
local ESC_THRESHOLD = 2

function M.feed_terminal(tseq, canonical)
  if canonical ~= '<Esc>' then
    -- Any other key (ordinary input the job consumes) breaks the streak and
    -- re-arms detection — see the REPL false-positive guard above.
    tseq.esc_streak = 0
    tseq.fired = false
    return nil
  end

  tseq.esc_streak = tseq.esc_streak + 1
  if tseq.esc_streak >= ESC_THRESHOLD and not tseq.fired then
    tseq.fired = true
    return { pattern = 'terminal_esc_repeat', cmd = '<C-\\><C-n>' }
  end
  return nil
end

return M
