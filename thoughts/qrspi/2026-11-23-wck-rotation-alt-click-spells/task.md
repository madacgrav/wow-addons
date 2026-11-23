# Task

In WarlockCombatKit, let each spell button on the rotation bar cast a different, user-chosen situational spell on right-click, and another on shift-click (left-click keeps casting the button's own spell). Alternate spells must be configurable per button and persist across sessions.

Ace3 check (wow-forever-addon skill, `references/ace3-vs-vanilla.md`): **not needed**. The addon is vanilla and already has its own Settings panel and spell dropdown; the rotation buttons are `SecureActionButtonTemplate` with `RegisterForClicks("AnyUp", "AnyDown")`, so per-button/modifier secure attributes cover the clicks. No profiles, modules or AceConfig options UI are required, so adding Ace3 would only add libraries.
