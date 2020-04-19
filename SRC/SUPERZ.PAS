{
	Copyright (c) 2020 Adrian Siekierka

	Based on a reconstruction of code from Super ZZT,
	Copyright 1991 Epic MegaGames, used with permission.

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
}

{$I-}
{$M 24576,163840,655360}
program SUPERZ;
uses Crt, Dos, Video, Keys, Sounds, Input, TxtWind, GameVars,
	Elements, Editor, Oop, Game, Uncrlib,
	S_REGIST, M_MONSTE, M_FOREST, M_PROVIN, S_ORDER, S_CONFIG;

procedure ParseArguments;
	var
		i: integer;
		pArg: string;
	begin
		for i := 1 to ParamCount do begin
			pArg := ParamStr(i);
			if pArg[1] = '/' then begin
				case UpCase(pArg[2]) of
					'T': begin
						SoundTimeCheckCounter := 0;
						UseSystemTimeForElapsed := false;
					end;
					'E': EditorEnabled := true;
				end;
			end else begin
				StartupWorldFileName := pArg;
				if (Length(StartupWorldFileName) > 4) and (StartupWorldFileName[Length(StartupWorldFileName) - 3] = '.') then begin
					StartupWorldFileName := Copy(StartupWorldFileName, 1, Length(StartupWorldFileName) - 4);
				end;
			end;
		end;
	end;

procedure GameConfigure;
	var
		regFile: text;
	begin
		ResetConfig := true;
		Assign(regFile, 'REGISTER.DOC');
		Reset(regFile);
		Close(regFile);
		IsRegistered := IOResult = 0;

		InputInitDevices;
		VideoInstall(80, Blue);
		Window(1, 1, 80, 25);
		UnCrunch(S_CONFIGCSIData, VideoTextPointer^, S_CONFIGCSISize);
		if IsRegistered then begin
			VideoWriteText(35, 24, $70, ' Registered version -- Please do not copy!');
		end;

		Window(3, 8, 78, 23);
		VideoClear(Blue);
		TextColor(Yellow);
		if not InputConfigure then begin
			GameTitleExitRequested := true
		end else begin
			TextColor(LightGreen);
			if not VideoConfigure then
				GameTitleExitRequested := true;
		end;

		Window(1, 1, 80, 25);
	end;

begin
	WorldFileDescCount := WORLD_FILE_DESC_COUNT;
	WorldFileDescKeys[1] := 'PROVING';
	WorldFileDescValues[1] := 'PROVING  ZZT'#39's Proving Grounds';
	WorldFileDescKeys[2] := 'FOREST';
	WorldFileDescValues[2] := 'FOREST   ZZT'#39's Lost Forest';
	WorldFileDescKeys[3] := 'MONSTER';
	WorldFileDescValues[3] := 'MONSTER  ZZT'#39's Monster Zoo';

	WorldFileMenuScrPtrs[1] := @M_PROVINCSIData;
	WorldFileMenuScrLens[1] := M_PROVINCSISize;
	WorldFileMenuScrPtrs[2] := @M_FORESTCSIData;
	WorldFileMenuScrLens[2] := M_FORESTCSISize;
	WorldFileMenuScrPtrs[3] := @M_MONSTECSIData;
	WorldFileMenuScrLens[3] := M_MONSTECSISize;

	WorldFileMenuScrPtrs[0] := @S_ORDERCSIData;
	WorldFileMenuScrLens[0] := S_ORDERCSISize;

	Randomize;
	SetCBreak(false);
	InitialTextAttr := TextAttr;

	StartupWorldFileName := 'MONSTER';
	MenuScrPointer := WorldFileMenuScrPtrs[3];
	MenuScrLen := WorldFileMenuScrLens[3];
	ResourceDataFileName := '';

	GameTitleExitRequested := false;
	EditorEnabled := false;
	IsRegistered := false;

	ParseArguments;
	GameConfigure;

	if not GameTitleExitRequested then begin
		VideoInstall(80, Blue);
		TextWindowInit(1, 2, 38, 22);
		New(IoTmpBuf);

		VideoHideCursor;
		TickSpeed := 4;
		DebugEnabled := false;

		SavedBoardFileName := 'TEMP';
		SavedGameFileName := StartupWorldFileName;

		GenerateTransitionTable;
		WorldCreate;

		GameTitleLoop;

		Dispose(IoTmpBuf);
	end;

	SoundUninstall;
	SoundClearQueue;

	VideoUninstall;
	if IsRegistered then begin
		Writeln;
		Writeln('  Registered Version -- Thank you for playing Super ZZT.');
		Writeln;
	end else begin
		UnCrunch(S_REGISTCSIData, VideoTextPointer^, S_REGISTCSISize);
	end;

	TextAttr := InitialTextAttr;
	GotoXY(1, 24);
	VideoShowCursor;
end.
