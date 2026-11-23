
# Marks501 — Development Instructions

## Target
- Game: World of Warcraft Forever
- Client: 1.60.1
- Interface: 16001
- Language: Lua 5.1 compatible
- Use modern C_Container APIs.

## API Research
- Verify WoW API signatures before using them.
- Prefer documentation specific to WoW Forever.
- Do not invent API functions.
- Do not use legacy WoW 3.3.5 APIs.
- Report uncertain or restricted APIs.

## Architecture
- Keep the addon small and modular.
- Separate inventory scanning from UI logic.
- Avoid unnecessary dependencies.
- Use descriptive function names.

## Workflow
1. Read docs/SPEC.md.
2. Inspect existing code.
3. Propose changes before complex edits.
4. Implement only the requested functionality.
5. Run available static checks and tests.
6. Report what must be tested in WoW.

## Safety
- Never sell items unless explicitly requested.
- Do not perform destructive inventory actions.
- Do not assume item IDs uniquely identify items.
- Never execute git push automatically.
- Preserve existing user settings.
