# Not yet released

- XYZ export for quantum chemistry: File → Export as → XYZ (and Copy to clipboard → XYZ), `export {format: "xyz"}` in the API and `reactio convert in.cdx -o out.xyz`. Each structure gets its hydrogens, a conformer search (OpenChemLib torsion library, MMFF94s+, lowest kept), the charge and spin multiplicity in the comment line, and a check that the 3D stereocentres and double bonds match the drawing. Structures MMFF94 cannot type (boron, metals) still get a 3D shape, marked as not minimised. The work runs in a background worker, so the editor stays responsive; a box at the bottom right shows which structure and conformer is being worked on, with Cancel, and when it is done it offers Save and Copy (the browser shows a Save dialog only right after a click, so it is not opened automatically after a long search). `maxSeconds` (30 s by default) is for the whole export and is shared out over the structures.

# Reactio Draw 1.3

## What changed since 1.2

- Clean Up keeps the configuration: after the new layout it checks R/S at every centre with wedges and E/Z at every double bond, and puts back what turned over (the mirror image, a branch turned back over its double bond, or the wedges of a centre swapped); when it cannot, the structure stays as drawn and a message says why.
- Fused rings are laid out as they are usually drawn: the layout starts from the largest ring system and puts it on the hexagon grid, hexagons regular and a five-membered ring between them taking up the strain (acenaphthene with its naphthalene flat), and symmetric when it can be (fluorene, carbazole); substituents grow from it. Bridged systems keep the layout they had.
- Reagents written as text: a caption such as MeMgBr, K2CO3 or nBuLi stays text on the sheet and is counted in the reagent table with its formula and mass. The new button Count text as a structure (at the end of the Text group) attaches the structure to a text or removes it; Shift+click draws the structure instead. These reagents are also in the reaction SMILES.
- More abbreviations and reagent names, from the Beilstein Chemical Lookup Collection (BChemLookup, CC0).
- Structure checks: a wedge or hash to a drawn H atom is checked on the right atom (a correct drawing was marked "not at a stereocentre").
- Links in the Windows, Mac and Linux apps (Info: what is new, the project page, the credits) open in the computer's own browser.
- The version is shown in Info, with a link to what is new; the local API has `version` and the command line `reactio --version`.
- How to cite: CITATION.cff, and each release is archived on Zenodo with its own DOI.
- The code is easier to read: the CSS and JavaScript of index.html are laid out one statement per line, and ARCHITECTURE.md is a map of the file for anyone who wants to change it.

## 1.2

- Opening CDXML and CDX files:
  - a bold double or triple bond stays double or triple, its main line bold;
  - labels with a generic group (OR, OR2, NR2, CO2R, NHAr) stay one label, and R, R1, R', Ar and X are no longer marked as unrecognized (Ar is the aryl group, not argon);
  - captions written in formula style keep their text, with the digits as subscripts; centred and right-aligned captions stay where they were;
  - curved arrows drawn on a structure, curved equilibrium arrows (two arcs), brackets, and ‡, † and charges next to them are kept;
  - dots hidden in white stay hidden.
- A group bonded to a metal (PPh2 on Ru, NMe2 on Pd) is no longer marked as having too many bonds.
- Opening a file shows the whole drawing (fit to the window).
- The mouse wheel scrolls the row of tabs when they do not all fit.
- New color theme, Color-blind safe: the eight colors of Okabe and Ito, which people with any kind of color blindness can tell apart.

## 1.1

- Top bar: a click on a group's grip ⋮ folds the group into one named menu (and back); Settings → Interface → Top bar → Compact puts everything but the file buttons into four menus in one row.
- Arrows: while you drag, the arrow itself is shown, faint, with its curve and heads. Curved (mechanism) arrows start and end on an atom or the middle of a bond, a small gap off it (Settings → Drawing → Ends of curved arrows: touching, small or larger gap). At an atom with a label the arrow stops short of the letters.
- Orbitals: lobes in the classic teardrop (dumbbell) shape; the menu has s (empty or filled), dxy, a single lobe (filled or empty), dz² (the ring or the lobes filled), p, and sp³ (the big or the small lobe filled); filling is always one phase; shaded orbitals in CDX and CDXML files open as shaded. An orbital put on an atom moves with it; selected, a round handle turns it about the atom and a square one changes its size. Overlap lines start and end at the tip or the middle of a lobe, or at the centre or edge of an s orbital; drawn with the dashed bond tool they stay dashed.

## 1.0.1

- Clean Up Reaction keeps conditions that are not one compound (Pd(PPh3)4, K2CO3; rt, 2 h) over or under the arrow, and the arrow grows to fit them; before, the product could land on top of such text.

1.0 was the first public version.

## Downloads

| File | For |
| --- | --- |
| `ReactioDraw-Windows-x64.zip` | Windows 11 on Intel or AMD: unzip, run `ReactioDraw.exe` |
| `ReactioDraw-Windows-ARM.zip` | Windows 11 on ARM (for example Parallels on an Apple-silicon Mac) |
| `ReactioDraw-Mac.zip` | macOS: double-click `Install Reactio Draw.command`; it builds the app on your Mac |
| `ReactioDraw-Linux-x64.tar.gz` | Linux on Intel or AMD: unpack, run `./install.sh` (needs WebKitGTK) |
| `ReactioDraw-Linux-ARM.tar.gz` | Linux on ARM |
| `ReactioDraw-Web.zip` | the browser version as one file, to keep offline |

The complete source code is the “Source code” archive GitHub attaches below: everything needed to build every version offline.

Every download carries `Reactio Draw - Getting started.pdf` (every function and button explained) and `Reactio Draw - Hotkeys.reactio`, a one-page hotkey chart that opens in Reactio Draw.

## Notes

- The Windows program is not signed with a certificate: Windows may say “Windows protected your PC” (More info → Run anyway).
- The Mac app is built on your own Mac by the installer (Apple's free Command Line Tools), so macOS does not block it.
- Paste name reads about 600 built-in names and abbreviations without extra software; other names need Java (OPSIN). Name it needs Python with openclatura and Java (each name is read back with OPSIN to check it). Everything else works without extra software, and nothing goes online.
