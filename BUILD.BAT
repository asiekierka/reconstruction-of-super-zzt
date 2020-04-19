@echo off
if not exist BIN mkdir BIN
del BIN\*.*

if not exist DIST mkdir DIST
del DIST\*.*

echo.
echo [ Building BIN2PAS.EXE ]
echo.
TPC /B /EBIN /ITOOLS /UTOOLS TOOLS\BIN2PAS.PAS
if errorlevel 1 goto error

echo.
echo [ Building CSIPACK.EXE ]
echo.
TPC /B /EBIN /ITOOLS /UTOOLS TOOLS\CSIPACK.PAS
if errorlevel 1 goto error

echo.
echo [ Converting screens ]
echo.

BIN\CSIPACK /C SCREENS\M_FOREST.BIN BIN\M_FOREST.CSI
if errorlevel 1 goto error
BIN\BIN2PAS BIN\M_FOREST.CSI BIN\M_FOREST.PAS
if errorlevel 1 goto error
BIN\CSIPACK /C SCREENS\M_MONSTE.BIN BIN\M_MONSTE.CSI
if errorlevel 1 goto error
BIN\BIN2PAS BIN\M_MONSTE.CSI BIN\M_MONSTE.PAS
if errorlevel 1 goto error
BIN\CSIPACK /C SCREENS\M_PROVIN.BIN BIN\M_PROVIN.CSI
if errorlevel 1 goto error
BIN\BIN2PAS BIN\M_PROVIN.CSI BIN\M_PROVIN.PAS
if errorlevel 1 goto error
BIN\CSIPACK /C SCREENS\S_CONFIG.BIN BIN\S_CONFIG.CSI
if errorlevel 1 goto error
BIN\BIN2PAS BIN\S_CONFIG.CSI BIN\S_CONFIG.PAS
if errorlevel 1 goto error
BIN\CSIPACK /C SCREENS\S_ORDER.BIN BIN\S_ORDER.CSI
if errorlevel 1 goto error
BIN\BIN2PAS BIN\S_ORDER.CSI BIN\S_ORDER.PAS
if errorlevel 1 goto error
BIN\CSIPACK /C SCREENS\S_REGIST.BIN BIN\S_REGIST.CSI
if errorlevel 1 goto error
BIN\BIN2PAS BIN\S_REGIST.CSI BIN\S_REGIST.PAS
if errorlevel 1 goto error

echo.
echo [ Building SUPERZ.EXE ]
echo.
TPC /B /EBIN /GD /ISRC;BIN /USRC;BIN SRC\SUPERZ.PAS
if errorlevel 1 goto error

echo.
echo [ Compressing SUPERZ.EXE ]
echo.
cd BIN
..\TOOLS\LZEXE.EXE SUPERZ.EXE
cd ..

echo.
echo [ Creating DIST/ ]
echo.
copy BIN\SUPERZ.EXE DIST\SUPERZ.EXE
copy LICENSE.TXT DIST\LICENSE.TXT
goto done
:error
echo.
echo [ Error detected! Stopping. ]
:done
