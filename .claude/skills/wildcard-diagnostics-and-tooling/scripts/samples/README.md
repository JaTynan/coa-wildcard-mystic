# SYNTHETIC samples: every number here is invented

These files exist only to test the scripts in the folder above without the server. `make_synthetic_samples.py`
writes them (seeded, so it writes the same files each time); `../selftest.py` checks the scripts find what was
planted in them. The line shapes match the real files (see `../../references/formats.md`); the values do not come
from the Wildcard server. **Never quote a number from a `SYNTHETIC-` file as a measurement.** Real results from
the server are in `../../references/reference-run-2026-11-22.md`.

Regenerate: `python make_synthetic_samples.py` then `python ../selftest.py`.
