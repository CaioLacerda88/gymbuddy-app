# Work In Progress

Active work being done by agents. Each section is removed once the branch is merged.

---

## Step 12.2b: Home Screen Redesign
**Branch:** `feature/step12.2b-home-redesign`
**Source:** Per PLAN.md Step 12.2b

### Goal
Transform home from generic dashboard into gym-floor action screen. One-handed, glanceable, answers "what do I do today?" in 2 seconds.

### Checklist
- [ ] Header: date + user display name (remove large "GymBuddy" title)
- [ ] THIS WEEK hero section above stat cells
- [ ] Progress counter separated from SuggestedNextPill (different rows)
- [ ] Chip sizes: next=60dp, remaining=48dp, done=44dp
- [ ] Next chip shows exercise count as secondary line
- [ ] Empty plan state: 72dp+ tappable container
- [ ] Contextual stats replace lifetime stats (last session + week volume)
- [ ] Week volume: new query/provider (sum of weight*reps this week)
- [ ] Routines list hidden when active plan exists
- [ ] Start Empty Workout: FilledButton, visible without scrolling
- [ ] Unit/widget tests
- [ ] `make ci` passes
- [ ] Code review
- [ ] QA gate
- [ ] PR opened
