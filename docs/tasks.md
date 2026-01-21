##

Fix bugs with manual order:
- [x] when you save a photo, right panel should show the new state.
- [ ] If you are sorting by manual order, selecting a photo should not return to default
- [ ] If you set a manual order and another photo already has the target number, increment the manual order of all photos with a manual order >= of target number (and < old manual order if it is larger than target number)
- [ ] changing order in form should trigger gallery refresh

STATUS: PLAN COMPLETE
PLAN: .claude/plans/fix-manual-order-bugs.md

##

On admin view, add option to outline gallery photos with red or green to show public/private status

STATUS: READY FOR PLAN

##

On admin view, allow drag and drop in gallery to adjust manual ordering

STATUS: READY FOR PLAN

##

When multiple photos are selected in admin view, allow for bulk setting of is\_public.

STATUS: READY FOR PLAN

##

Use `mix phx.gen.release` to generate release infrastructure to run migrations in production without relying on mix

##

update CLAUDE.md and readme to fix docker command for dev - no dash, and no user

##

Switch from simple is\_public boolean to publish and hide timestamps which can be set by admin. Photos will only appear to public if within those dates. Both date fields are nullable. 
In admin view, should be able to edit dates directly, or simply check/uncheck the is\_public box. Checking box and saving should set publish timestamp to now. Unchecking should set hidden timestamp to now.

STATUS: READY FOR PLAN

##

Figure out admin UI to make some folders daily or weekly releases, with easy-to-manage schedules.

STATUS: NEEDS BRAINSTORMING
