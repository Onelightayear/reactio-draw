# NMR shift tables (derivative database of nmrshiftdb2)

Contains information from nmrshiftdb2 (https://nmrshiftdb.nmr.uni-koeln.de), which is made available
here under the nmrshiftdb2 Database License (`LICENSES/nmrshiftdb2-Database-License.txt`).
Copyright and database rights remain with the nmrshiftdb2 contributors. These tables are a derivative
database and are offered under the same license; the method of alteration is the code in this folder.

Source: nmrshiftdb2withsignals.sd, export of 2026-03-15,
https://downloads.sourceforge.net/project/nmrshiftdb2/data/nmrshiftdb2withsignals.sd
(158,569,118 bytes, SHA-256 0e86688360e23c88ccf0eb82a1251315fa57ec6f5b376dc8886f3311793a0afe).

Method (`build.js`, encoder `nmrcore.js`, rd-sphere-v1 — written for Reactio Draw, not taken from
nmrshiftdb2's predictor software):
- measured spectra only: spectra with a Program / NMRProgram entry (calculated) are skipped;
- all solvents and temperatures pooled (most records do not report them);
- each atom is described by the tree of shortest paths from it, up to 5 bonds (element, aromaticity,
  attached H, charge, bond type, ring closures); levels 1–5;
- per molecule one median per environment; the table holds the median over molecules, the number of
  molecules (capped at 255) and the spread; levels 3–5 keep only environments seen in at least two molecules;
- ¹H shifts are stored on the heavy atom that carries the hydrogens.

Prediction uses the deepest level that matches. Files: `13C.bin`, `1H.bin`, `19F.bin`, `31P.bin`
(per level: count, then entries u32 hash, i16 shift×scale, u8 molecules, u8 spread; scale ¹H 100, others 10).
The key is a 32-bit hash of the environment code. When two different codes share a key, `build.js` leaves that
key out (12 such keys in the 2026-03-15 export), so those atoms are predicted from their
shallower environment instead of a mix of two.

Validation (`validate.js`, `errtab.json`): about 10% of molecules (by InChIKey) left out, tables rebuilt
from the rest, shifts of the left-out atoms predicted:

| Nucleus | Left-out atoms | Coverage | MAE / ppm | MAE at sphere 1 / 2 / 3 / 4 / 5 |
| --- | ---: | ---: | ---: | --- |
| ¹³C | 36,725 | 99.7% | 2.69 | 8.2 / 3.2 / 1.8 / 1.0 / 0.6 |
| ¹H | 12,808 | 99.6% | 0.29 | 0.72 / 0.39 / 0.23 / 0.17 / 0.10 |
| ¹⁹F | 643 | 98.3% | 7.24 | 50.8 / 8.3 / 2.6 / 3.1 / 1.4 |
| ³¹P | 1,355 | 90.7% | 11.41 | 19.1 / 8.8 / 6.7 / 1.7 / 2.8 |

The left-out molecules come from the same database, so these are not independent measurements.
Rebuild: `node build.js nmrshiftdb2withsignals.sd out` (add `1` as a third argument for the held-out split).
