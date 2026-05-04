## Summary

<!-- 1-2 sentences. -->

## Type

- [ ] feat
- [ ] fix
- [ ] docs
- [ ] chore (CI, refactor, etc.)
- [ ] hardware report

## Checklist

- [ ] `shellcheck --severity=warning bin/fannode install.sh uninstall.sh` passes
- [ ] `shfmt -d -i 4 -ci bin/fannode install.sh uninstall.sh` is clean
- [ ] `bash tests/smoke.sh` passes
- [ ] CHANGELOG.md updated if user-visible
- [ ] If touching the applet: `python3 -m json.tool` on metadata + settings-schema passes

## Notes

<!-- Anything the reviewer should know. Hardware tested on, etc. -->
