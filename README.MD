# The Reconstruction of Super ZZT

The Reconstruction of Super ZZT is a reverse-engineered recreation of the source code to the last official release of
Super ZZT, Super ZZT 2.0.

## Frequently Asked Questions

### What is Super ZZT?

Super ZZT is a sequel to ZZT, an adventure game created by Tim Sweeney. It was released in October 1991, providing
new built-in elements and a large, scrolling playfield.

You can learn more about ZZT and its modern-day community from [the README](https://github.com/asiekierka/reconstruction-of-zzt/blob/master/README.MD)
of the Reconstruction of ZZT.

### How can I create Super ZZT worlds of my own?

Unlike ZZT, Super ZZT's built-in editor needs to be activated by using the "/E" command-line switch.
After doing so, you can press "E" just like in ZZT.

Please note that the popular third-party tool, KevEdit, does not support Super ZZT worlds. Other editors
exist which do, like ZAP and ZEdit2.

### What is part of this open-source release?

This release's binary distribution includes the Super ZZT engine executable, SUPERZ.EXE.

The source code includes the source format for SUPERZ.EXE, as well as relevant tools.

### Is this open-source release byte-accurate, like the previous one?

Short answer: Sort of.

Long answer: Almost all of the code is byte-accurate. However, Super ZZT utilizes TheDraw's Crunched Screen Image
decompression routine for its ANSI art graphical displays. As I did not manage to find clear
licensing terms for said routine, UNCRLIB.PAS contains a clean implementation of it. This ensures that the
binary produced by this repository is MIT-licensed, even if a non-consequential part of it differs. However,
it is possible to replace UNCRLIB.PAS with the original implementation and get a .EXE byte-accurate to
Super ZZT 2.0.

### Why did the source code have to be reconstructed?

This is because the original source code to Super ZZT [was lost a long time ago](https://web.archive.org/web/19991010013339/http://www.epicgames.com/zzt.htm) alongside ZZT's.

### I'm a ZZTer from back in the day and I have some backups from that period. Are they still useful?

**Yes!** There are many ZZT and Super ZZT worlds, utilities, and other documents which have not yet been preserved. If you'd like to share them and see them be
adequately catalogued and preserved, please contact me at (kontakt at asie dot pl) - or get in touch with the Museum of ZZT community.

## Directory structure

* **BIN** - output directory for EXE and TPU files,
* **DIST** - output directory for the binary distribution,
* **SCREENS** - 80x25 .BIN screen video data for graphical screens used in Super ZZT,
* **SRC** - the reconstructed Super ZZT source code,
    * **SUPERZ.PAS** - main source file,
* **TOOLS** - tools used when building:
    * **BIN2PAS.PAS** - BIN2PAS, a tool for converting binary files into Pascal units,
    * **CSIPACK.PAS** - CSIPACK, a tool for compressing and decompressing Crunched Screen Images,
    * **LZEXE.EXE** - LZEXE, a .EXE compression tool by Fabrice Bellard,
* **BUILD.BAT** - source code build script,
* **LICENSE.TXT** - licensing terms for the source code release.

## License

The Reconstruction of Super ZZT is licensed under the terms of the MIT license as described in LICENSE.TXT, with the exception of certain files included with this release:

* **TOOLS/LZEXE.DOC**, **TOOLS/LZEXE.EXE**:

```
    LZEXE.EXE v0.91    (c) 1989 Fabrice BELLARD

    Ce programme fait parti du domaine public (FREEWARE),  donc vous pouvez
  l'utiliser, le copier et le distribuer sans problème. Et vous pouvez même
  en faire un usage commercial, c'est à dire compacter des fichiers EXE que
  vous allez vendre. Mais la vente de LZEXE.EXE est interdite.
```

## Compiling

### Requirements

* DOS-compatible environment (f.e. DOSBox),
* Turbo Pascal 5.5 (if you don't have it, it's officially available for free via Embarcadero's Antique Software website).

### Instructions

1. Ensure that TPC.EXE from Turbo Pascal is available on your PATH (f.e. `SET PATH=C:\TP;%PATH%`).
2. From the source code directory, run `BUILD.BAT`.
3. The DIST directory will contain files comprising the release as outlined in the FAQ.

### Compilation FAQ

#### What are all the "unk"-prefixed variables?

These are variables which are not used at all anywhere in the source code, but are assumed to exist in the stack or data segments, affecting relevant
variable offsets and stack checks. They are required for byte-level equivalence, but you are free to remove them and get a functionally equivalent
version of the engine - with the exception of some structures, like TStat, which are serialized to disk.

## Greetings

As always, I'd like to thank everyone who has spent the last few years contributing to the rebirth of the small ZZT community.
