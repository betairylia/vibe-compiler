# Vibe Compiler

Vibe and own your mind.

## Workflow: When you have an existing codebase

Let's say you want to modify part of some program. Maybe you wrote it, others wrote it, LLMs wrote it, doesn't matter.  

You do this:

1. Make a folder `Specs/` beside the project codebase repo.
2. Read the codebase of your interest. Write your mindmap of that part in pseudo code under `Specs/<part-name>.vibe`. Write at your own granularity: write in detail for interesting parts, write a blackbox in something you don't want to bother for now.
3. `/spec-align`. Once it passes, your `.vibe` is then linked with the actual codebase, and you know you have understood the code in your preferred granularity.
4. Modify your `.vibe`. Add parts or constraints you'd like to have.
5. `/spec-impl`. Think of a compiler -- LLM will compile your `.vibe` into actual project code.

## Why do this

- If you are here then probably you don't want to write your code by your hands anymore. That's slow.
- Then you write prompts. But then you quickly find yourself lost in the sea of prompts. You feel out of control, you feel unsafe.
- So why don't we own something. Something that's controllable, something that's fun to polish, something clear enough to understand, and straight out from our mind in the most comfortable form. That's `.vibe`.

> Think of a giant prompt that you can own and polish and never get lost.

## Example: Stamina bar

One may write this in their `Specs/stamina.vibe`:

---

The player has stamina. Running uses it. Walking or standing refills it.
At 0 stamina the player cannot run until stamina is back at 20%.
The UI shows stamina as a bar above the player's head.

```csharp
Stamina : Component {
    float current, max;   // max = 100 by default
    bool exhausted;       // true at 0, false again at 20% of max
}

// Saved in the save file. strict: exactly these fields, no more.
strict SavedStamina { float current; }

StaminaSystem : time O(players) // every tick
{
    if (player is running && !exhausted) current -= 15 * dt;
    else                                 current += 10 * dt;
    clamp current to 0..max;
    update exhausted;
}

StaminaBar { A UI bar that follows the player's head. Hidden when full. }

// TODO: food gives more max stamina
```

---

Then `/spec-impl` and wait for LLMs to compile the pseudo code into actual project code.

## Disclaimer

This is no silver bullet. LLM drifts from your intent in an inevitable way, and that's not something you'd expect from a real compiler. Use at your own risk.

But owning your "code" again really feels good and refreshing.
