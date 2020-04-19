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
{$V-}
unit Game;

interface
	uses GameVars, TxtWind;
	const
		PROMPT_NUMERIC = 0;
		PROMPT_ALPHANUM = 1;
		PROMPT_ANY = 2;
	procedure GenerateTransitionTable;
	procedure AdvancePointer(var address: pointer; count: integer);
	procedure BoardClose;
	procedure BoardOpen(boardId: integer);
	procedure BoardChange(boardId: integer);
	procedure BoardCreate;
	procedure WorldCreate;
	procedure TransitionDrawToFill(chr: char; color: integer);
	procedure BoardDrawTile(x, y: integer);
	procedure TransitionDrawToBoard;
	procedure ClearDisplayMessage;
	procedure PromptString(x, y, arrowColor, color, width: integer; mode: byte; var buffer: TSmallString);
	function PromptYesNo(message: string; defaultReturn: boolean; color: integer): boolean;
	procedure PauseOnError;
	function DisplayIOError: boolean;
	procedure WorldUnload;
	function WorldLoad(filename, extension: TSmallString; titleOnly: boolean): boolean;
	procedure SidebarPromptString(prompt: string; extension: TSmallString; var filename: string; promptMode: byte);
	procedure WorldSave(filename, extension: TSmallString);
	procedure GameWorldSave(prompt: TSmallString; var filename: TSmallString; extension: TSmallString);
	function GameWorldLoad(extension: TSmallString; param_2: TSmallString): boolean;
	procedure CopyStatDataToTextWindow(statId: integer; var state: TTextWindowState);
	procedure AddStat(tx, ty: integer; element: byte; color, tcycle: integer; template: TStat);
	procedure RemoveStat(statId: integer);
	function GetStatIdAt(x, y: integer): integer;
	procedure BoardRemoveTile(x, y: integer);
	function BoardPrepareTileForPlacement(x, y: integer): boolean;
	procedure MoveStat(statId: integer; newX, newY: integer);
	function Signum(val: integer): integer;
	function Difference(a, b: integer): integer;
	procedure GameUpdateSidebar;
	procedure DisplayMessage(time: integer; line1, line2: TSmallString);
	procedure DamageStat(attackerStatId: integer);
	procedure BoardDamageTile(x, y: integer);
	procedure BoardAttack(attackerStatId: integer; x, y: integer);
	function BoardShoot(element: byte; tx, ty, deltaX, deltaY: integer; source: integer): boolean;
	procedure CalcDirectionRnd(var deltaX, deltaY: integer);
	procedure CalcDirectionSeek(x, y: integer; var deltaX, deltaY: integer);
	procedure TransitionDrawBoardChange;
	procedure BoardEnter;
	procedure BoardPassageTeleport(x, y: integer);
	procedure GameDebugPrompt;
	procedure DrawPlayfieldBorder;
	procedure BoardUpdateDrawOffset;
	procedure GamePlayLoop(isTitle: boolean);
	procedure GameTitleLoop;

const
	ProgressAnimColors: array[0 .. 7] of byte = ($18, $1C, $19, $1D, $1A, $1E, $1B, $1F);
	ProgressAnimStrings: array[0 .. 7] of string[5] =
		('....|', '...*/', '..*.-', '.*..\', '*...|', '..../', '....-', '....\');
	ColorNames: array[1 .. 7] of string[8] =
		('Blue', 'Green', 'Cyan', 'Red', 'Purple', 'Yellow', 'White');
	{}
	DiagonalDeltaX: array[0 .. 7] of integer = (-1, 0, 1, 1, 1, 0, -1, -1);
	DiagonalDeltaY: array[0 .. 7] of integer = (1, 1, 1, 0, -1, -1, -1, 0);
	NeighborDeltaX: array[0 .. 3] of integer = (0, 0, -1, 1);
	NeighborDeltaY: array[0 .. 3] of integer = (-1, 1, 0, 0);
	{}
	TileBoardEdge: TTile = (Element: E_BOARD_EDGE; Color: $00);
	{}
	StatTemplateDefault: TStat = (
		X: 0; Y: 0; StepX: 0; StepY: 0;
		Cycle: 0; P1: 0; P2: 0; P3: 0;
		Follower: -1; Leader: -1
	);
	WebChars: TSmallString = #250#179#179#179#196#217#191#180#196#192#218#195#196#193#194#197;
	LineChars: TSmallString = #249#208#210#186#181#188#187#185#198#200#201#204#205#202#203#206;

implementation
uses Dos, Crt, Video, Sounds, Input, Uncrlib, Elements, Editor, Oop;

procedure GenerateTransitionTable;
	var
		i, ix, iy: integer;
		t: TCoord;
	begin
		i := 0;
		for iy := 0 to 19 do
			for ix := 0 to 23 do begin
				Inc(i);
				TransitionTable[i].X := ix;
				TransitionTable[i].Y := iy;
			end;

		{ shuffle }
		for ix := 1 to TRANSITION_TABLE_COUNT do begin
			iy := Random(TRANSITION_TABLE_COUNT) + 1;
			t := TransitionTable[iy];
			TransitionTable[iy] := TransitionTable[ix];
			TransitionTable[ix] := t;
		end;
	end;

procedure AdvancePointer(var address: pointer; count: integer);
	begin
		address := Ptr(Seg(address^), Ofs(address^) + count);
	end;

procedure BoardClose;
	var
		ix, iy: integer;
		ptr: pointer;
		rle: TRleTile;
	begin
		ptr := IoTmpBuf;

		Move(Board.Name, ptr^, SizeOf(Board.Name));
		AdvancePointer(ptr, SizeOf(Board.Name));

		ix := 1;
		iy := 1;
		rle.Count := 1;
		rle.Tile := Board.Tiles[ix][iy];
		repeat
			ix := ix + 1;
			if ix > BOARD_WIDTH then begin
				ix := 1;
				iy := iy + 1;
			end;
			if (Board.Tiles[ix][iy].Color = rle.Tile.Color) and
				(Board.Tiles[ix][iy].Element = rle.Tile.Element) and
				(rle.Count < 255) and (iy <= BOARD_HEIGHT) then
			begin
				rle.Count := rle.Count + 1;
			end else begin
				Move(rle, ptr^, SizeOf(rle));
				AdvancePointer(ptr, SizeOf(rle));
				rle.Tile := Board.Tiles[ix][iy];
				rle.Count := 1;
			end;
		until iy > BOARD_HEIGHT;

		Move(Board.Info, ptr^, SizeOf(Board.Info));
		AdvancePointer(ptr, SizeOf(Board.Info));

		Move(Board.StatCount, ptr^, SizeOf(Board.StatCount));
		AdvancePointer(ptr, SizeOf(Board.StatCount));

		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				if DataLen > 0 then begin
					for iy := 1 to (ix - 1) do begin
						if Board.Stats[iy].Data = Data then
							DataLen := -iy;
					end;
				end;
				Move(Board.Stats[ix], ptr^, SizeOf(TStat));
				AdvancePointer(ptr, SizeOf(TStat));
				if DataLen > 0 then begin
					Move(Data^, ptr^, DataLen);
					FreeMem(Data, DataLen);
					AdvancePointer(ptr, DataLen);
				end;
			end;
		end;

		FreeMem(World.BoardData[World.Info.CurrentBoard], World.BoardLen[World.Info.CurrentBoard]);
		World.BoardLen[World.Info.CurrentBoard] := Ofs(ptr^) - Ofs(IoTmpBuf^);
		GetMem(World.BoardData[World.Info.CurrentBoard], World.BoardLen[World.Info.CurrentBoard]);
		Move(IoTmpBuf^, World.BoardData[World.Info.CurrentBoard]^, World.BoardLen[World.Info.CurrentBoard]);
	end;

procedure BoardOpen(boardId: integer);
	var
		ptr: pointer;
		ix, iy: integer;
		rle: TRleTile;
	begin
		if boardId > World.BoardCount then
			boardId := World.Info.CurrentBoard;

		ptr := World.BoardData[boardId];

		Move(ptr^, Board.Name, SizeOf(Board.Name));
		AdvancePointer(ptr, SizeOf(Board.Name));

		ix := 1;
		iy := 1;
		rle.Count := 0;
		repeat
			if rle.Count <= 0 then begin
				Move(ptr^, rle, SizeOf(rle));
				AdvancePointer(ptr, SizeOf(rle));
			end;
			Board.Tiles[ix][iy] := rle.Tile;
			ix := ix + 1;
			if ix > BOARD_WIDTH then begin
				ix := 1;
				iy := iy + 1;
			end;
			rle.Count := rle.Count - 1;
		until iy > BOARD_HEIGHT;

		Move(ptr^, Board.Info, SizeOf(Board.Info));
		AdvancePointer(ptr, SizeOf(Board.Info));

		Move(ptr^, Board.StatCount, SizeOf(Board.StatCount));
		AdvancePointer(ptr, SizeOf(Board.StatCount));

		for ix := 0 to Board.StatCount do
			with Board.Stats[ix] do begin
				Move(ptr^, Board.Stats[ix], SizeOf(TStat));
				AdvancePointer(ptr, SizeOf(TStat));
				if DataLen > 0 then begin
					if MaxAvail < DataLen then begin
						VideoClear(Black);
						Writeln('Out of Memory!');
						Writeln('Mem ', MaxAvail, '..', DataLen);
						Writeln('Obj ', ix, '..', Board.StatCount);
						Writeln('Bd  ', boardId);
					end;

					GetMem(Data, DataLen);
					Move(ptr^, Data^, DataLen);
					AdvancePointer(ptr, DataLen);
				end;
			end;

		for ix := 0 to Board.StatCount do
			with Board.Stats[ix] do begin
				if DataLen < 0 then begin
					Data := Board.Stats[-DataLen].Data;
					DataLen := Board.Stats[-DataLen].DataLen;
				end;
			end;

		World.Info.CurrentBoard := boardId;
	end;

procedure BoardChange(boardId: integer);
	begin
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_PLAYER;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[E_PLAYER].Color;
		BoardClose;
		BoardOpen(boardId);
	end;

procedure BoardCreate;
	var
		ix, iy, i: integer;
	begin
		Board.Name := '';
		MessageLine1 := '';
		Board.Info.MaxShots := 255;
		Board.Info.ReenterWhenZapped := false;
		Board.Info.TimeLimitSec := 0;
		for i := 0 to 3 do
			Board.Info.NeighborBoards[i] := 0;

		for ix := 0 to BOARD_WIDTH+1 do begin
			Board.Tiles[ix][0] := TileBoardEdge;
			Board.Tiles[ix][BOARD_HEIGHT+1] := TileBoardEdge;
		end;
		for iy := 0 to BOARD_HEIGHT+1 do begin
			Board.Tiles[0][iy] := TileBoardEdge;
			Board.Tiles[BOARD_WIDTH+1][iy] := TileBoardEdge;
		end;

		for ix := 1 to BOARD_WIDTH do
			for iy := 1 to BOARD_HEIGHT do begin
				Board.Tiles[ix][iy].Element := E_EMPTY;
				Board.Tiles[ix][iy].Color := 0;
			end;

		Board.Tiles[BOARD_WIDTH div 2][BOARD_HEIGHT div 2].Element := E_PLAYER;
		Board.Tiles[BOARD_WIDTH div 2][BOARD_HEIGHT div 2].Color := ElementDefs[E_PLAYER].Color;
		Board.StatCount := 0;
		Board.Stats[0].X := BOARD_WIDTH div 2;
		Board.Stats[0].Y := BOARD_HEIGHT div 2;
		Board.Stats[0].Cycle := 1;
		Board.Stats[0].Under.Element := E_EMPTY;
		Board.Stats[0].Under.Color := 0;
		Board.Stats[0].Data := nil;
		Board.Stats[0].DataLen := 0;
		Board.Info.DrawXOffset := Board.Stats[0].X - (BOARD_DRAW_WIDTH div 2);
		if Board.Info.DrawXOffset < 1 then
			Board.Info.DrawXOffset := 1;
		Board.Info.DrawYOffset := Board.Stats[0].Y - (BOARD_DRAW_HEIGHT div 2);
		if Board.Info.DrawYOffset < 1 then
			Board.Info.DrawYOffset := 1;
	end;

procedure WorldCreate;
	var
		i: integer;
	begin
		InitElementsGame;
		World.BoardCount := 0;
		World.BoardLen[0] := 0;
		InitEditorStatSettings;
		ResetMessageNotShownFlags;
		BoardCreate;
		World.Info.IsSave := false;
		World.Info.CurrentBoard := 0;
		World.Info.Ammo := 0;
		World.Info.Gems := 0;
		World.Info.Health := 100;
		World.Info.EnergizerTicks := 0;
		World.Info.Score := 0;
		World.Info.BoardTimeSec := 0;
		World.Info.BoardTimeHsec := 0;
		World.Info.StonesOfPower := -1;
		for i := 1 to 7 do
			World.Info.Keys[i] := false;
		for i := 1 to MAX_FLAG do
			World.Info.Flags[i] := '';
		BoardChange(0);
		Board.Name := 'Title screen';
		LoadedGameFileName := '';
		World.Info.Name := '';
	end;

procedure TransitionDrawToFill(chr: char; color: integer);
	var
		i: integer;
	begin
		for i := 1 to TRANSITION_TABLE_COUNT do
			VideoWriteText(
				TransitionTable[i].X + BOARD_DRAW_X,
				TransitionTable[i].Y + BOARD_DRAW_Y,
				color, chr
			);
	end;

procedure BoardDrawTile(x, y: integer);
	var
		drawnChar: byte;
		drawnColor: integer;
	begin
		if (
			(x >= Board.Info.DrawXOffset)
			and (y >= Board.Info.DrawYOffset)
			and (x < (Board.Info.DrawXOffset + BOARD_DRAW_WIDTH))
			and (y < (Board.Info.DrawYOffset + BOARD_DRAW_HEIGHT))
		) then with Board.Tiles[x][y] do begin
			if Element = E_EMPTY then begin
				drawnChar := $20;
				drawnColor := $0F;
			end else if ElementDefs[Element].HasDrawProc then begin
				ElementDefs[Element].DrawProc(x, y, drawnChar);
				drawnColor := Color;
			end else if Element < E_TEXT_MIN then begin
				drawnChar := Ord(ElementDefs[Element].Character);
				drawnColor := Color;
			end else begin
				{ Text drawing }
				drawnChar := Board.Tiles[x][y].Color;
				if Element = E_TEXT_WHITE then
					drawnColor := $0F
				else if VideoMonochrome then
					drawnColor := $F0
				else
					drawnColor := (((Element - E_TEXT_MIN) + 1) * 16) + $F;
			end;

			VideoWriteText(
				x + BOARD_DRAW_X - Board.Info.DrawXOffset,
				y + BOARD_DRAW_Y - Board.Info.DrawYOffset,
				drawnColor, Chr(drawnChar)
			);
		end;
	end;

procedure TransitionDrawToBoard;
	var
		i: integer;
	begin
		for i := 1 to TRANSITION_TABLE_COUNT do
			with TransitionTable[i] do
				BoardDrawTile(
					X + Board.Info.DrawXOffset,
					Y + Board.Info.DrawYOffset
				);
	end;

procedure ClearDisplayMessage;
	begin
		VideoWriteText(12, 23, $1F, '                            ');
		VideoWriteText(12, 24, $1F, '                            ');
	end;

procedure DrawStatusMessage(msg: string);
	begin
		ClearDisplayMessage;
		VideoWriteText(26 - (Length(msg) div 2), 24, $1E, msg);
	end;

procedure PromptString(x, y, arrowColor, color, width: integer; mode: byte; var buffer: TSmallString);
	var
		i: integer;
		oldBuffer: string;
		firstKeyPress: boolean;
	begin
		oldBuffer := buffer;
		firstKeyPress := true;

		repeat
			for i := 0 to (width - 1) do begin
				VideoWriteText(x + i, y, color, ' ');
				VideoWriteText(x + i, y - 1, arrowColor, ' ');
			end;
			VideoWriteText(x + width, y - 1, arrowColor, ' ');
			VideoWriteText(x + Length(buffer), y - 1, (arrowColor div $10) * 16 + $0F, #31);
			VideoWriteText(x, y, color, buffer);

			InputReadWaitKey;

			if (Length(buffer) < width) and (InputKeyPressed >= #32) and (InputKeyPressed < #128) then begin
				if firstKeyPress then
					buffer := '';
				case mode of
					PROMPT_NUMERIC: begin
						if (InputKeyPressed in ['0' .. '9']) then begin
							buffer := buffer + InputKeyPressed;
						end;
					end;
					PROMPT_ANY: begin
						buffer := buffer + InputKeyPressed;
					end;
					PROMPT_ALPHANUM: begin
						if (UpCase(InputKeyPressed) in ['A' .. 'Z'])
							or (InputKeyPressed in ['0' .. '9'])
							or (InputKeyPressed = '-') then
						begin
							buffer := buffer + UpCase(InputKeyPressed);
						end;
					end;
				end;
			end else if (InputKeyPressed = KEY_LEFT) or (InputKeyPressed = KEY_BACKSPACE) then begin
				buffer := Copy(buffer, 1, Length(buffer) - 1);
			end;

			firstKeyPress := false;
		until (InputKeyPressed = KEY_ENTER) or (InputKeyPressed = KEY_ESCAPE);
		if InputKeyPressed = KEY_ESCAPE then begin
			buffer := oldBuffer;
		end;
	end;

function PromptYesNo(message: string; defaultReturn: boolean; color: integer): boolean;
	begin
		VideoWriteText(15, 24, color, message);
		VideoWriteText(15 + Length(message), 24, (color and $70) + $8E, '_');

		repeat
			InputReadWaitKey;
		until UpCase(InputKeyPressed) in [KEY_ESCAPE, 'N', 'Y'];
		if UpCase(InputKeyPressed) = 'Y' then
			defaultReturn := true
		else
			defaultReturn := false;

		ClearDisplayMessage;
		PromptYesNo := defaultReturn;
	end;

procedure PauseOnError;
	begin
		SoundQueue(1, SoundParse('s004x114x9'));
		Delay(2000);
	end;

function DisplayIOError: boolean;
	var
		statusMsg: TSmallString;
		textWindow: TTextWindowState;
	begin
		if IOResult = 0 then begin
			DisplayIOError := false;
			exit;
		end;

		case IOResult of
			2: statusMsg := 'File not found!';
			3: statusMsg := 'Path not found!';
			101: statusMsg := 'Disk full!';
		else
			statusMsg := 'DOS Error!';
		end;

		DrawStatusMessage(statusMsg);
		PauseOnError;
		ClearDisplayMessage;
		DisplayIOError := true;

		textWindow.Title := 'Error';
		TextWindowInitState(textWindow);
		TextWindowAppend(textWindow, '$DOS Error:');
		TextWindowAppend(textWindow, '');
		TextWindowAppend(textWindow, 'This may be caused by missing');
		TextWindowAppend(textWindow, 'ZZT files or a bad disk.  If');
		TextWindowAppend(textWindow, 'you are trying to save a game,');
		TextWindowAppend(textWindow, 'your disk may be full -- try');
		TextWindowAppend(textWindow, 'using a blank, formatted disk');
		TextWindowAppend(textWindow, 'for saving the game!');

		TextWindowDrawOpen(textWindow);
		TextWindowSelect(textWindow, false, false);
		TextWindowDrawClose(textWindow);
		TextWindowFree(textWindow);
	end;

procedure WorldUnload;
	var
		i: integer;
	begin
		BoardClose;
		for i := 0 to World.BoardCount do
			FreeMem(World.BoardData[i], World.BoardLen[i]);
	end;

function WorldLoad(filename, extension: TSmallString; titleOnly: boolean): boolean;
	var
		f: file;
		ptr: pointer;
		i: integer;
		loadProgress: integer;
	procedure SidebarAnimateLoading;
		begin
			VideoWriteText(22, 24, ProgressAnimColors[loadProgress], ProgressAnimStrings[loadProgress]);
			loadProgress := (loadProgress + 1) mod 8;
		end;
	begin
		WorldLoad := false;
		loadProgress := 0;

		VideoWriteText(15, 24, $1F, 'Loading.....');

		Assign(f, filename + extension);
		Reset(f, 1);

		if not DisplayIOError then begin
			WorldUnload;
			BlockRead(f, IoTmpBuf^, WORLD_FILE_HEADER_SIZE);

			if not DisplayIOError then begin
				ptr := IoTmpBuf;
				Move(ptr^, World.BoardCount, SizeOf(World.BoardCount));
				AdvancePointer(ptr, SizeOf(World.BoardCount));

				if World.BoardCount < 0 then begin
					if World.BoardCount <> -2 then begin
						DrawStatusMessage('Wrong ZZT version!');
						PauseOnError;
						ClearDisplayMessage;
						exit;
					end else begin
						Move(ptr^, World.BoardCount, SizeOf(World.BoardCount));
						AdvancePointer(ptr, SizeOf(World.BoardCount));
					end;
				end;

				Move(ptr^, World.Info, SizeOf(World.Info));
				AdvancePointer(ptr, SizeOf(World.Info));

				for i := 0 to World.BoardCount do begin
					SidebarAnimateLoading;
					BlockRead(f, World.BoardLen[i], 2);
					GetMem(World.BoardData[i], World.BoardLen[i]);
					BlockRead(f, World.BoardData[i]^, World.BoardLen[i]);
				end;

				Close(f);

				BoardOpen(World.Info.CurrentBoard);
				LoadedGameFileName := filename;
				WorldLoad := true;

				HighScoresLoad;
				ClearDisplayMessage;

				for i := 1 to WorldFileDescCount do begin
					if World.Info.Name = WorldFileDescKeys[i] then begin
						MenuScrPointer := WorldFileMenuScrPtrs[i];
						MenuScrLen := WorldFileMenuScrLens[i];
					end;
				end;
			end;
		end;
	end;

procedure SidebarPromptString(prompt: string; extension: TSmallString; var filename: string; promptMode: byte);
	begin
		ClearDisplayMessage;

		VideoWriteText(13, 24, $1F, prompt);
		VideoWriteText(Length(prompt) + 13 + 2, 24, $0F, '        ' + extension);

		PromptString(Length(prompt) + 13 + 2, 24, $1E, $0F, 8, promptMode, filename);

		ClearDisplayMessage;
	end;

procedure WorldSave(filename, extension: TSmallString);
	var
		f: file;
		i: integer;
		unk1: integer;
		ptr: pointer;
		version: integer;
	label OnError;
	begin
		BoardClose;
		DrawStatusMessage('Saving...');

		Assign(f, filename + extension);
		Rewrite(f, 1);

		if not DisplayIOError then begin
			ptr := IoTmpBuf;
			FillChar(IoTmpBuf^, WORLD_FILE_HEADER_SIZE, 0);
			version := -2;
			Move(version, ptr^, SizeOf(version));
			AdvancePointer(ptr, SizeOf(version));

			Move(World.BoardCount, ptr^, SizeOf(World.BoardCount));
			AdvancePointer(ptr, SizeOf(World.BoardCount));

			Move(World.Info, ptr^, SizeOf(World.Info));
			AdvancePointer(ptr, SizeOf(World.Info));

			BlockWrite(f, IoTmpBuf^, WORLD_FILE_HEADER_SIZE);
			if DisplayIOError then goto OnError;

			for i := 0 to World.BoardCount do begin
				BlockWrite(f, World.BoardLen[i], 2);
				if DisplayIOError then goto OnError;

				BlockWrite(f, World.BoardData[i]^, World.BoardLen[i]);
				if DisplayIOError then goto OnError;
			end;

			Close(f);
		end;

		BoardOpen(World.Info.CurrentBoard);
		ClearDisplayMessage;
		exit;

	OnError:
		Close(f);
		Erase(f);
		BoardOpen(World.Info.CurrentBoard);
		ClearDisplayMessage;
	end;

procedure GameWorldSave(prompt: TSmallString; var filename: TSmallString; extension: TSmallString);
	var
		newFilename: TSmallString;
	begin
		newFilename := filename;
		SidebarPromptString(prompt, extension, newFilename, PROMPT_ALPHANUM);
		if (InputKeyPressed <> KEY_ESCAPE) and (Length(newFilename) <> 0) then begin
			filename := newFilename;
			if extension = '.SZT' then
				World.Info.Name := filename;
			WorldSave(filename, extension);
		end;
	end;

function GameWorldLoad(extension: TSmallString; param_2: TSmallString): boolean;
	var
		textWindow: TTextWindowState;
		fileSearchRec: SearchRec;
		entryName: string;
		i: integer;
	begin
		param_2 := param_2 + extension;
		for i := 1 to Length(param_2) do
			param_2[i] := UpCase(param_2[i]);

		TextWindowInitState(textWindow);
		if extension = '.SZT' then
			textWindow.Title := 'ZZT Worlds'
		else
			textWindow.Title := 'Saved Games';
		GameWorldLoad := false;
		textWindow.Selectable := true;

		FindFirst('*' + extension, AnyFile, fileSearchRec);
		while DosError = 0 do begin
			entryName := Copy(fileSearchRec.Name, 1, Length(fileSearchRec.name) - 4);

			for i := 1 to WorldFileDescCount do
				if entryName = WorldFileDescKeys[i] then
					entryName := WorldFileDescValues[i];

			TextWindowAppend(textWindow, entryName);
			if entryName = param_2 then
				textWindow.LinePos := textWindow.LineCount;
			FindNext(fileSearchRec);
		end;
		TextWindowAppend(textWindow, 'Exit');

		TextWindowDrawOpen(textWindow);
		TextWindowSelect(textWindow, false, false);
		TextWindowDrawClose(textWindow);

		if (textWindow.LinePos < textWindow.LineCount) and not TextWindowRejected then begin
			entryName := textWindow.Lines[textWindow.LinePos]^;
			if Pos(' ', entryName) <> 0 then
				entryName := Copy(entryName, 1, Pos(' ', entryName) - 1);

			GameWorldLoad := WorldLoad(entryName, extension, false);
			if extension <> '.SAV' then
				SavedGameFileName := entryName;
			TransitionDrawToFill(#219, $44);
		end;

		TextWindowFree(textWindow);
	end;

procedure CopyStatDataToTextWindow(statId: integer; var state: TTextWindowState);
	var
		dataStr: string;
		dataPtr: pointer;
		dataChr: char;
		i: integer;
	begin
		with Board.Stats[statId] do begin
			TextWindowInitState(state);
			dataStr := '';
			dataPtr := Data;

			for i := 0 to DataLen do begin
				Move(dataPtr^, dataChr, 1);
				if dataChr = KEY_ENTER then begin
					TextWindowAppend(state, dataStr);
					dataStr := '';
				end else begin
					dataStr := dataStr + dataChr;
				end;
				AdvancePointer(dataPtr, 1);
			end;
		end;
	end;

procedure AddStat(tx, ty: integer; element: byte; color, tcycle: integer; template: TStat);
	begin
		if Board.StatCount < MAX_STAT then begin
			Board.StatCount := Board.StatCount + 1;
			Board.Stats[Board.StatCount] := template;
			with Board.Stats[Board.StatCount] do begin
				X := tx;
				Y := ty;
				Cycle := tcycle;
				Under := Board.Tiles[tx][ty];
				DataPos := 0;
			end;

			if template.Data <> nil then begin
				GetMem(Board.Stats[Board.StatCount].Data, template.DataLen);
				Move(template.Data^, Board.Stats[Board.StatCount].Data^, template.DataLen);
			end;

			if ElementDefs[Board.Tiles[tx][ty].Element].PlaceableOnTop then
				Board.Tiles[tx][ty].Color := (color and $0F) + (Board.Tiles[tx][ty].Color and $70)
			else
				Board.Tiles[tx][ty].Color := color;
			Board.Tiles[tx][ty].Element := element;

			if ty > 0 then
				BoardDrawTile(tx, ty);
		end;
	end;

procedure RemoveStat(statId: integer);
	var
		i: integer;
	label StatDataInUse;
	begin
		with Board.Stats[statId] do begin
			if DataLen <> 0 then begin
				for i := 1 to Board.StatCount do begin
					if (Board.Stats[i].Data = Data) and (i <> statId) then
						goto StatDataInUse;
				end;
				FreeMem(Data, DataLen);
			end;

		StatDataInUse:
			if statId < CurrentStatTicked then
				CurrentStatTicked := CurrentStatTicked - 1;

			Board.Tiles[X][Y] := Under;
			if Y > 0 then
				BoardDrawTile(X, Y);

			for i := 1 to Board.StatCount do begin
				if Board.Stats[i].Follower >= statId then begin
					if Board.Stats[i].Follower = statId then
						Board.Stats[i].Follower := -1
					else
						Dec(Board.Stats[i].Follower);
				end;

				if Board.Stats[i].Leader >= statId then begin
					if Board.Stats[i].Leader = statId then
						Board.Stats[i].Leader := -1
					else
						Dec(Board.Stats[i].Leader);
				end;
			end;

			for i := (statId + 1) to Board.StatCount do
				Board.Stats[i - 1] := Board.Stats[i];
			Board.StatCount := Board.StatCount - 1;
		end;
	end;

function GetStatIdAt(x, y: integer): integer;
	var
		i: integer;
	begin
		i := -1;
		repeat
			i := i + 1;
		until ((Board.Stats[i].X = x) and (Board.Stats[i].Y = y)) or (i > Board.StatCount);

		if i > Board.StatCount then
			GetStatIdAt := -1
		else
			GetStatIdAt := i;
	end;

procedure BoardRemoveTile(x, y: integer);
	var
		i, ix, iy: integer;
		iElem, iColor: byte;
		floorColor: integer;
	label Label1;
	begin
		floorColor := 0;
		for i := 0 to 3 do begin
			ix := x + NeighborDeltaX[i];
			iy := y + NeighborDeltaY[i];
			iElem := Board.Tiles[ix][iy].Element;
			iColor := Board.Tiles[ix][iy].Color;

			if ElementDefs[iElem].Cycle <> -1 then begin
				iElem := Board.Stats[GetStatIdAt(ix, iy)].Under.Element;
				iColor := Board.Stats[GetStatIdAt(ix, iy)].Under.Color;	
			end;

			if (iElem = E_EMPTY)
				or (iElem = E_SLIDER_NS)
				or (iElem = E_SLIDER_EW)
				or (iElem = E_BOULDER)
			then begin
				floorColor := 0;
				goto Label1;
			end else if (iElem = E_FLOOR) then begin
				floorColor := iColor;
			end;
		end;

	Label1:
		if floorColor = 0 then begin
			Board.Tiles[x][y].Element := E_EMPTY;
		end else begin
			Board.Tiles[x][y].Element := E_FLOOR;
			Board.Tiles[x][y].Color := floorColor;
		end;
	end;

function BoardPrepareTileForPlacement(x, y: integer): boolean;
	var
		statId: integer;
		result: boolean;
	begin
		statId := GetStatIdAt(x, y);
		if statId > 0 then begin
			RemoveStat(statId);
			result := true;
		end else if statId < 0 then begin
			if not ElementDefs[Board.Tiles[x][y].Element].PlaceableOnTop then
				BoardRemoveTile(x, y);
			result := true;
		end else begin { statId = 0 (player) cannot be modified }
			result := false;
		end;
		BoardDrawTile(x, y);
		BoardPrepareTileForPlacement := result;
	end;

procedure MoveStat(statId: integer; newX, newY: integer);
	var
		iUnder: TTile;
		oldX, oldY: integer;
		oldBgColor: integer;
		redrawRequired: boolean;
		i: integer;
		scrollOffset: boolean;
	begin
		with Board.Stats[statId] do begin
			scrollOffset := true;
			if newX < 0 then begin
				newX := -newX;
				scrollOffset := false;
			end;

			oldBgColor := Board.Tiles[newX][newY].Color and $F0;

			iUnder := Board.Stats[statId].Under;
			Board.Stats[statId].Under := Board.Tiles[newX][newY];

			if Board.Tiles[newX][newY].Element = E_EMPTY then
				Board.Tiles[newX][newY].Color := Board.Tiles[X][Y].Color and $0F
			else
				Board.Tiles[newX][newY].Color := (Board.Tiles[X][Y].Color and $0F) + (Board.Tiles[newX][newY].Color and $70);

			Board.Tiles[newX][newY].Element := Board.Tiles[X][Y].Element;
			Board.Tiles[X][Y] := iUnder;
			BoardDrawTile(X, Y);

			if (statId = 0) and scrollOffset then begin
				redrawRequired := false;

				if ((newX - Board.Info.DrawXOffset) < 9)
					and (Board.Info.DrawXOffset > 1)
				then begin
					if (X - 1) = newX then begin
						Board.Info.DrawXOffset := Board.Info.DrawXOffset - 1;
						VideoScroll(
							BOARD_DRAW_X, BOARD_DRAW_Y,
							BOARD_DRAW_WIDTH, BOARD_DRAW_HEIGHT,
							1, 0
						);
						for i := Board.Info.DrawYOffset to (Board.Info.DrawYOffset + BOARD_DRAW_HEIGHT) do
							BoardDrawTile(Board.Info.DrawXOffset, i);
					end else begin
						Board.Info.DrawXOffset := newX - (BOARD_DRAW_WIDTH div 2);
						if Board.Info.DrawXOffset < 1 then
							Board.Info.DrawXOffset := 1;
						if (Board.Info.DrawXOffset + BOARD_DRAW_WIDTH) >= BOARD_WIDTH then
							Board.Info.DrawXOffset := BOARD_WIDTH - BOARD_DRAW_WIDTH;
						redrawRequired := true;
					end;
				end;


				if ((newX - Board.Info.DrawXOffset) >= 14)
					and ((Board.Info.DrawXOffset + BOARD_DRAW_WIDTH) <= BOARD_WIDTH)
				then begin
					if (X + 1) = newX then begin
						Board.Info.DrawXOffset := Board.Info.DrawXOffset + 1;
						VideoScroll(
							BOARD_DRAW_X, BOARD_DRAW_Y,
							BOARD_DRAW_WIDTH, BOARD_DRAW_HEIGHT,
							-1, 0
						);
						for i := Board.Info.DrawYOffset to (Board.Info.DrawYOffset + BOARD_DRAW_HEIGHT) do
							BoardDrawTile(Board.Info.DrawXOffset + (BOARD_DRAW_WIDTH - 1), i);
					end else begin
						Board.Info.DrawXOffset := newX - (BOARD_DRAW_WIDTH div 2);
						redrawRequired := true;
					end;
				end;

				if ((newY - Board.Info.DrawYOffset) < 8)
					and (Board.Info.DrawYOffset > 1)
				then begin
					if (Y - 1) = newY then begin
						Board.Info.DrawYOffset := Board.Info.DrawYOffset - 1;
						VideoScroll(
							BOARD_DRAW_X, BOARD_DRAW_Y,
							BOARD_DRAW_WIDTH, BOARD_DRAW_HEIGHT,
							0, 1
						);
						for i := Board.Info.DrawXOffset to (Board.Info.DrawXOffset + BOARD_DRAW_WIDTH) do
							BoardDrawTile(i, Board.Info.DrawYOffset);
					end else begin
						Board.Info.DrawYOffset := newY - (BOARD_DRAW_HEIGHT div 2);
						redrawRequired := true;
					end;
				end;

				if ((newY - Board.Info.DrawYOffset) >= 14)
					and ((Board.Info.DrawYOffset + BOARD_DRAW_HEIGHT) <= BOARD_HEIGHT)
				then begin
					if (Y + 1) = newY then begin
						Board.Info.DrawYOffset := Board.Info.DrawYOffset + 1;
						VideoScroll(
							BOARD_DRAW_X, BOARD_DRAW_Y,
							BOARD_DRAW_WIDTH, BOARD_DRAW_HEIGHT,
							0, -1
						);
						for i := Board.Info.DrawXOffset to (Board.Info.DrawXOffset + BOARD_DRAW_WIDTH) do
							BoardDrawTile(i, Board.Info.DrawYOffset + (BOARD_DRAW_HEIGHT - 1));
					end else begin
						Board.Info.DrawYOffset := newY - (BOARD_DRAW_HEIGHT div 2);
						redrawRequired := true;
					end;
				end;

				if redrawRequired then begin
					if Board.Info.DrawXOffset < BOARD_DRAW_OX_MIN then
						Board.Info.DrawXOffset := BOARD_DRAW_OX_MIN;
					if Board.Info.DrawXOffset >= BOARD_DRAW_OX_MAX then
						Board.Info.DrawXOffset := BOARD_DRAW_OX_MAX;
					if Board.Info.DrawYOffset < BOARD_DRAW_OY_MIN then
						Board.Info.DrawYOffset := BOARD_DRAW_OY_MIN;
					if Board.Info.DrawYOffset >= BOARD_DRAW_OY_MAX then
						Board.Info.DrawYOffset := BOARD_DRAW_OY_MAX;
					TransitionDrawToBoard;
				end;
			end;

			X := newX;
			Y := newY;
			BoardDrawTile(X, Y);
		end;
	end;

function Signum(val: integer): integer;
	begin
		if val > 0 then
			Signum := 1
		else if val < 0 then
			Signum := -1
		else
			Signum := 0;
	end;

function Difference(a, b: integer): integer;
	begin
		if (a - b) >= 0 then
			Difference := a - b
		else
			Difference := b - a;
	end;

procedure GameUpdateSidebar;
	var
		numStr: string[8];
		drawnChar: char;
		i: integer;
	begin
		if GameStateElement = E_PLAYER then begin
			if World.Info.Health < 0 then
				World.Info.Health := 0;
			for i := 1 to 5 do begin
				if (i * 20) <= World.Info.Health then
					VideoWriteText(i + 6, 15, $6E, #219)
				else if ((i * 20) - 10) > World.Info.Health then
					VideoWriteText(i + 6, 15, $6E, ' ')
				else
					VideoWriteText(i + 6, 15, $6E, #221)
			end;

			Str(World.Info.Gems, numStr);
			VideoWriteText(7, 17, $6E, '   ');
			VideoWriteText(11 - Length(numStr), 17, $6E, numStr);

			Str(World.Info.Ammo, numStr);
			VideoWriteText(7, 18, $6E, '   ');
			VideoWriteText(11 - Length(numStr), 18, $6E, numStr);

			Str(World.Info.Score, numStr);
			VideoWriteText(7, 21, $6E, '   ');
			VideoWriteText(11 - Length(numStr), 21, $6E, numStr);

			VideoWriteText(0, 22, $6F, '            ');
			for i := 1 to MAX_FLAG do begin
				if (Length(World.Info.Flags[i]) <> 0)
					and (World.Info.Flags[i][1] = 'Z')
				then begin
					VideoWriteText(1, 22, $6F, Copy(World.Info.Flags[i], 2, Length(World.Info.Flags[i]) - 1));
				end;
			end;
			if World.Info.StonesOfPower >= 0 then begin
				Str(World.Info.StonesOfPower, numStr);
				VideoWriteText(11 - Length(numStr), 22, $6E, numStr);
			end;

			for i := 1 to 7 do begin
				if World.Info.Keys[i] then
					drawnChar := ElementDefs[E_KEY].Character
				else
					drawnChar := ' ';
				VideoWriteText(((i - 1) mod 4) + 7, ((i - 1) div 4) + 19, $68 + i, drawnChar);
			end;

			if SoundEnabled then
				VideoWriteText(3, 10, $6E, 'Be Quiet ')
			else
				VideoWriteText(3, 10, $6E, 'Be Noisy ');

			if DebugEnabled then begin
				Str(MemAvail, numStr);
				VideoWriteText(0, 0, $1E, 'm' + numStr + ' ');
			end;
		end;
	end;

procedure DisplayMessage(time: integer; line1, line2: TSmallString);
	begin
		if GetStatIdAt(0, 0) <> -1 then begin
			RemoveStat(GetStatIdAt(0, 0));
		end;

		if (Length(line1) <> 0) or (Length(line2) <> 0) then begin
			AddStat(0, 0, E_MESSAGE_TIMER, 0, 1, StatTemplateDefault);
			Board.Stats[Board.StatCount].P2 := Time div (TickTimeDuration + 1);
			MessageLine1 := line1;
			MessageLine2 := line2;
		end;
		ClearDisplayMessage;
	end;

procedure DamageStat(attackerStatId: integer);
	var
		oldX, oldY: integer;
	begin
		with Board.Stats[attackerStatId] do begin
			if attackerStatId = 0 then begin
				if World.Info.Health > 0 then begin
					World.Info.Health := World.Info.Health - 10;

					GameUpdateSidebar;
					DisplayMessage(100, '', 'Ouch!');

					Board.Tiles[X][Y].Color := $70 + (ElementDefs[E_PLAYER].Color mod $10);

					if World.Info.Health > 0 then begin
						World.Info.BoardTimeSec := 0;
						if Board.Info.ReenterWhenZapped then begin
							SoundQueue(4, #32#1#35#1#39#1#48#1#16#1);

							{ Move player to start }
							BoardRemoveTile(X, Y);
							oldX := X;
							oldY := Y;
							X := Board.Info.StartPlayerX;
							Y := Board.Info.StartPlayerY;
							DrawPlayerSurroundings(oldX, oldY, 0);
							DrawPlayerSurroundings(X, Y, 0);

							GamePaused := true;
						end;
						SoundQueue(4, #16#1#32#1#19#1#35#1);
					end else begin
						SoundQueue(5, #32#3#35#3#39#3#48#3#39#3#42#3#50#3#55#3#53#3#56#3#64#3#69#3#16#10);
					end;
				end;
			end else begin
				case Board.Tiles[X][Y].Element of
					E_BULLET: SoundQueue(3, #32#1);
					E_OBJECT: begin end;
				else
					SoundQueue(3, #64#1#16#1#80#1#48#1)
				end;
				RemoveStat(attackerStatId);
			end;
		end;
	end;

procedure BoardDamageTile(x, y: integer);
	var
		statId: integer;
	begin
		statId := GetStatIdAt(x, y);
		if statId <> -1 then begin
			DamageStat(statId);
		end else begin
			BoardRemoveTile(x, y);
		end;
	end;

procedure BoardAttack(attackerStatId: integer; x, y: integer);
	begin
		if (attackerStatId = 0) and (World.Info.EnergizerTicks > 0) then begin
			World.Info.Score := ElementDefs[Board.Tiles[x][y].Element].ScoreValue + World.Info.Score;
			GameUpdateSidebar;
		end else begin
			DamageStat(attackerStatId);
		end;

		if (attackerStatId > 0) and (attackerStatId <= CurrentStatTicked) then
			CurrentStatTicked := CurrentStatTicked - 1;

		if (Board.Tiles[x][y].Element = E_PLAYER) and (World.Info.EnergizerTicks > 0) then begin
			World.Info.Score := ElementDefs[Board.Tiles[Board.Stats[attackerStatId].X][Board.Stats[attackerStatId].Y].Element]
				.ScoreValue + World.Info.Score;
			GameUpdateSidebar;
		end else begin
			BoardDamageTile(x, y);
			SoundQueue(2, #16#1);
		end;
	end;

function BoardShoot(element: byte; tx, ty, deltaX, deltaY: integer; source: integer): boolean;
	begin
		if ElementDefs[Board.Tiles[tx + deltaX][ty + deltaY].Element].Walkable
			or (Board.Tiles[tx + deltaX][ty + deltaY].Element = E_LAVA) then
		begin
			AddStat(tx + deltaX, ty + deltaY, element, ElementDefs[element].Color, 1, StatTemplateDefault);
			with Board.Stats[Board.StatCount] do begin
				P1 := source;
				StepX := deltaX;
				StepY := deltaY;
				P2 := 100;
			end;
			BoardShoot := true;
		end else if (Board.Tiles[tx + deltaX][ty + deltaY].Element = E_BREAKABLE)
			or (
				ElementDefs[Board.Tiles[tx + deltaX][ty + deltaY].Element].Destructible
				and ((Board.Tiles[tx + deltaX][ty + deltaY].Element = E_PLAYER) = Boolean(source))
				and (World.Info.EnergizerTicks <= 0)
			) then
		begin
			BoardDamageTile(tx + deltaX, ty + deltaY);
			SoundQueue(2, #16#1);
			BoardShoot := true;
		end else begin
			BoardShoot := false;
		end;
	end;

procedure CalcDirectionRnd(var deltaX, deltaY: integer);
	begin
		deltaX := Random(3) - 1;

		if deltaX = 0 then
			deltaY := Random(2) * 2 - 1
		else
			deltaY := 0;
	end;

procedure CalcDirectionSeek(x, y: integer; var deltaX, deltaY: integer);
	begin
		deltaX := 0;
		deltaY := 0;

		if (Random(2) < 1) or (Board.Stats[0].Y = y) then
			deltaX := Signum(Board.Stats[0].X - x);

		if deltaX = 0 then
			deltaY := Signum(Board.Stats[0].Y - y);

		if World.Info.EnergizerTicks > 0 then begin
			deltaX := -deltaX;
			deltaY := -deltaY;
		end;
	end;

procedure TransitionDrawBoardChange;
	begin
		TransitionDrawToFill(#219, $05);
		TransitionDrawToBoard;
	end;

procedure BoardEnter;
	begin
		Board.Info.StartPlayerX := Board.Stats[0].X;
		Board.Info.StartPlayerY := Board.Stats[0].Y;

		World.Info.BoardTimeSec := 0;
		GameUpdateSidebar;
	end;

procedure BoardPassageTeleport(x, y: integer);
	var
		oldBoard: integer;
		col: byte;
		ix, iy: integer;
		newX, newY: integer;
	begin
		col := Board.Tiles[x][y].Color;

		oldBoard := World.Info.CurrentBoard;
		BoardChange(Board.Stats[GetStatIdAt(x, y)].P3);

		newX := 0;
		for ix := 1 to BOARD_WIDTH do
			for iy := 1 to BOARD_HEIGHT do
				if (Board.Tiles[ix][iy].Element = E_PASSAGE) and (Board.Tiles[ix][iy].Color = col)
					and ((newX = 0) or (ix <> x) or (iy <> y))
				then begin
					newX := ix;
					newY := iy;
				end;

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := Board.Stats[0].Under.Element;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := Board.Stats[0].Under.Color;
		if newX <> 0 then begin
			Board.Stats[0].X := newX;
			Board.Stats[0].Y := newY;
		end;

		GamePaused := true;
		SoundQueue(4, #48#1#52#1#55#1#49#1#53#1#56#1#50#1#54#1#57#1#51#1#55#1#58#1#52#1#56#1#64#1);
		BoardUpdateDrawOffset;
		TransitionDrawBoardChange;
		BoardEnter;
	end;

procedure GameDebugPrompt;
	var
		input: TSmallString;
		i: integer;
		toggle: boolean;
	begin
		input := '';

		ClearDisplayMessage;
		PromptString(15, 24, $1E, $0F, 11, PROMPT_ANY, input);
		ClearDisplayMessage;

		toggle := true;

		if (input[1] = '+') or (input[1] = '-') then begin
			if input[1] = '-' then
				toggle := false;
			input := Copy(input, 2, Length(input) - 1);

			for i := 1 to Length(input) do
				input[i] := UpCase(input[i]);

			if toggle = true then begin
				WorldSetFlag(input);
			end else begin
				if input <> 'ALL' then begin
					WorldClearFlag(input);
				end else begin
					for i := 1 to MAX_FLAG do
						World.Info.Flags[i] := '';
				end;
			end;

			DebugEnabled := WorldGetFlagPosition('DEBUG') >= 0;
		end;

		if input = 'health' then
			World.Info.Health := World.Info.Health + 50
		else if input = 'ammo' then
			World.Info.Ammo := World.Info.Ammo + 20
		else if input = 'keys' then
			for i := 1 to 7 do World.Info.Keys[i] := true
		else if input = 'time' then
			World.Info.BoardTimeSec := World.Info.BoardTimeSec - 30
		else if input = 'z' then
			World.Info.StonesOfPower := World.Info.StonesOfPower + 1
		else if input = 'noz' then
			World.Info.StonesOfPower := -1
		else if input = 'gems' then
			World.Info.Gems := World.Info.Gems + 5
		else if input = 'zap' then begin
			for i := 0 to 3 do begin
				BoardDamageTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
				Board.Tiles[Board.Stats[0].X + NeighborDeltaX[i]][Board.Stats[0].Y + NeighborDeltaY[i]].Element := E_EMPTY;
				BoardDrawTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
			end;
		end;

		SoundQueue(10, #39#4);
		GameUpdateSidebar;
	end;

procedure DrawPlayfieldBorder;
	var
		i: integer;
	begin
		VideoWriteText(BOARD_DRAW_X - 1, BOARD_DRAW_Y - 1, $1F,
			#220#220#220#220#220#220#220#220#220#220#220#220#220
			+ #220#220#220#220#220#220#220#220#220#220#220#220#220);
		VideoWriteText(BOARD_DRAW_X - 1, BOARD_DRAW_Y + BOARD_DRAW_HEIGHT, $1F,
			#223);
		VideoWriteText(BOARD_DRAW_X, BOARD_DRAW_Y + BOARD_DRAW_HEIGHT, $7F,
			#223#223#223#223#223#223#223#223#223#223#223#223#223
			+ #223#223#223#223#223#223#223#223#223#223#223#223);
		for i := BOARD_DRAW_Y to (BOARD_DRAW_Y + BOARD_DRAW_HEIGHT - 1) do begin
			VideoWriteText(BOARD_DRAW_X - 1, i, $0F, #219'                        '#219);
			VideoWriteText(BOARD_DRAW_X + BOARD_DRAW_WIDTH + 1, i + 1, $17, #221);
		end;
	end;

procedure BoardUpdateDrawOffset;
	begin
		Board.Info.DrawXOffset := Board.Stats[0].X - (BOARD_DRAW_WIDTH div 2);
		if Board.Info.DrawXOffset < BOARD_DRAW_OX_MIN then
			Board.Info.DrawXOffset := BOARD_DRAW_OX_MIN;
		if Board.Info.DrawXOffset > BOARD_DRAW_OX_MAX then
			Board.Info.DrawXOffset := BOARD_DRAW_OX_MAX;

		Board.Info.DrawYOffset := Board.Stats[0].Y - (BOARD_DRAW_HEIGHT div 2);
		if Board.Info.DrawYOffset < BOARD_DRAW_OY_MIN then
			Board.Info.DrawYOffset := BOARD_DRAW_OY_MIN;
		if Board.Info.DrawYOffset > BOARD_DRAW_OY_MAX then
			Board.Info.DrawYOffset := BOARD_DRAW_OY_MAX;
	end;

procedure GamePlayLoop(isTitle: boolean);
	var
		exitLoop: boolean;
		pauseBlink: boolean;
		pausePlayerStr: TSmallString;
		pausePlayerColor: integer;
	procedure GameDrawSidebar;
		var
			unk1: integer;
		begin
			VideoClear(Blue);
			if GameStateElement = E_PLAYER then begin
				VideoWriteText(0, 0, $1D, #220#220#220#220#220#220#220#220#220#220#220#220);
				VideoWriteText(0, 1, $6F, '  Commands  ');
				VideoWriteText(0, 2, $6D, #223#223#223#223#223#223#223#223#223#223#223#223);

				VideoWriteText(0, 3, $6F, ' '#24#25#26#27'       ');
				VideoWriteText(0, 4, $6E, '   Move     ');
				VideoWriteText(0, 5, $6F, ' Shift+'#24#25#26#27+' ');
				VideoWriteText(0, 6, $6B, '   Shoot    ');
				VideoWriteText(0, 7, $6E, '   Hint     ');
				VideoWriteText(1, 7, $6F,  'H');
				VideoWriteText(0, 8, $6B, '   Save Game');
				VideoWriteText(1, 8, $6F,  'S');
				VideoWriteText(0, 9, $6E, '   Restore  ');
				VideoWriteText(1, 9, $6F,  'R');
				VideoWriteText(0, 10, $6B, '   Be Quiet ');
				VideoWriteText(1, 10, $6F,  'B');
				VideoWriteText(0, 11, $6E, '   Quit     ');
				VideoWriteText(1, 11, $6F,  'Q');

				VideoWriteText(0, 12, $1D, #220#220#220#220#220#220#220#220#220#220#220#220);
				VideoWriteText(0, 13, $6F, '   Status   ');
				VideoWriteText(0, 14, $6D, #223#223#223#223#223#223#223#223#223#223#223#223);

				VideoWriteText(0, 15, $6F, 'Health      ');
				VideoWriteText(0, 16, $6F, '            ');
				VideoWriteText(0, 17, $6F, ' Gems       ');
				VideoWriteText(6, 17, $62, #4);
				VideoWriteText(0, 18, $6F, ' Ammo       ');
				VideoWriteText(6, 18, $6B, #132);
				VideoWriteText(0, 19, $6F, ' Keys       ');
				VideoWriteText(0, 20, $6F, '            ');
				VideoWriteText(0, 21, $6F, ' Score      ');
				VideoWriteText(0, 22, $6F, '            ');
				VideoWriteText(0, 23, $6F, '            ');
			end else if GameStateElement = E_MONITOR then begin
				VideoWriteText(4, 10, $1E, 'Press');
				VideoWriteText(4, 12, $1F, 'ENTER');
				VideoWriteText(1, 14, $1E, 'to continue');
			end;

			DrawPlayfieldBorder;
		end;
	begin
		GameDrawSidebar;
		GameUpdateSidebar;

		if Length(World.Info.Name) = 0 then begin
			if not WorldLoad(StartupWorldFileName, '.SZT', true) then
				WorldCreate;

			ReturnBoardId := World.Info.CurrentBoard;
			JustStarted := false;
		end;

		if isTitle then
			BoardChange(0)
		else
			BoardChange(ReturnBoardId);

		BoardEnter;

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := GameStateElement;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[GameStateElement].Color;

		if GameStateElement = E_MONITOR then begin
			DisplayMessage(0, '', '');
		end;

		BoardUpdateDrawOffset;
		TransitionDrawBoardChange;		

		TickTimeDuration := TickSpeed * 2;
		GamePlayExitRequested := false;
		exitLoop := false;

		CurrentTick := Random(100);
		CurrentStatTicked := Board.StatCount + 1;

		repeat
			if GamePaused then begin
				if SoundHasTimeElapsed(TickTimeCounter, 25) then
					pauseBlink := not pauseBlink;

				if pauseBlink then begin
					pausePlayerColor := ElementDefs[E_PLAYER].Color;
					pausePlayerStr := ElementDefs[E_PLAYER].Character;
				end else begin
					if Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element = E_PLAYER then begin
						pausePlayerColor := $0F;
						pausePlayerStr := ' ';
					end else begin
						pausePlayerStr := '';
						BoardDrawTile(Board.Stats[0].X, Board.Stats[0].Y);
					end;
				end;

				VideoWriteText(
					Board.Stats[0].X + BOARD_DRAW_X - Board.Info.DrawXOffset,
					Board.Stats[0].Y + BOARD_DRAW_Y - Board.Info.DrawYOffset,
					pausePlayerColor,
					pausePlayerStr
				);
				VideoWriteText(21, 24, $1E, 'Pausing...');
				InputUpdate;

				if InputKeyPressed = KEY_ESCAPE then
					GamePromptEndPlay;

				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					ElementDefs[Board.Tiles[Board.Stats[0].X + InputDeltaX][Board.Stats[0].Y + InputDeltaY].Element].TouchProc(
						Board.Stats[0].X + InputDeltaX, Board.Stats[0].Y + InputDeltaY, 0, InputDeltaX, InputDeltaY);
				end;

				if ((InputDeltaX <> 0) or (InputDeltaY <> 0))
					and ElementDefs[Board.Tiles[Board.Stats[0].X + InputDeltaX][Board.Stats[0].Y + InputDeltaY].Element].Walkable
				then begin
					{ Move player }
					if Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element = E_PLAYER then
						MoveStat(0, Board.Stats[0].X + InputDeltaX, Board.Stats[0].Y + InputDeltaY)
					else begin
						BoardDrawTile(Board.Stats[0].X, Board.Stats[0].Y);
						Board.Stats[0].X := Board.Stats[0].X + InputDeltaX;
						Board.Stats[0].Y := Board.Stats[0].Y + InputDeltaY;
						Board.Stats[0].Under.Element :=  Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element;
						Board.Stats[0].Under.Color :=  Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color;
						Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_PLAYER;
						Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[E_PLAYER].Color;
						BoardDrawTile(Board.Stats[0].X, Board.Stats[0].Y);
						DrawPlayerSurroundings(Board.Stats[0].X, Board.Stats[0].Y, 0);
						DrawPlayerSurroundings(Board.Stats[0].X - InputDeltaX, Board.Stats[0].Y - InputDeltaY, 0);
					end;

					{ Unpause }
					GamePaused := false;
					CurrentTick := Random(100);
					CurrentStatTicked := Board.StatCount + 1;
					World.Info.IsSave := true;
					ClearDisplayMessage;
				end;
			end else begin { not GamePaused }
				if CurrentStatTicked <= Board.StatCount then begin
					with Board.Stats[CurrentStatTicked] do begin
						if (Cycle <> 0) and ((CurrentTick mod Cycle) = (CurrentStatTicked mod Cycle)) then
							ElementDefs[Board.Tiles[X][Y].Element].TickProc(CurrentStatTicked);

						CurrentStatTicked := CurrentStatTicked + 1;
					end;
				end;
			end;

			if (CurrentStatTicked > Board.StatCount) and not GamePlayExitRequested then begin
				{ all stats ticked }
				if SoundHasTimeElapsed(TickTimeCounter, TickTimeDuration) then begin
					{ next cycle }
					CurrentTick := CurrentTick + 1;
					if CurrentTick > 420 then
						CurrentTick := 1;
					CurrentStatTicked := 0;

					InputUpdate;
				end;
			end;
		until (exitLoop or GamePlayExitRequested) and GamePlayExitRequested;

		SoundClearQueue;

		if GameStateElement = E_PLAYER then begin
			if World.Info.Health <= 0 then begin
				HighScoresAdd(World.Info.Score);
			end;
		end else if GameStateElement = E_MONITOR then begin
		end;

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_PLAYER;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[E_PLAYER].Color;

		SoundBlockQueueing := false;
	end;

procedure GameTitleLoop;
	var
		runPlay: boolean;
		runTitle: boolean;
		returningFromGame: boolean;	
	begin
		GameTitleExitRequested := false;
		JustStarted := true;
		GamePlayStartRequested := false;
		returningFromGame := false;
		repeat
			runTitle := false;
			if not GamePlayStartRequested then begin
				if returningFromGame then begin
					VideoInstall(80, Black);
					returningFromGame := false;
				end;
				runPlay := false;
				VideoClear(Black);
				UnCrunch(MenuScrPointer^, VideoTextPointer^, MenuScrLen);
				if IsRegistered and (MenuScrPointer = WorldFileMenuScrPtrs[3]) then begin
					VideoWriteText(6, 17, $0F, 'W');
					VideoWriteText(10, 17, $0E, 'World Menu      ');
				end;
				InputReadWaitKey;
				case UpCase(InputKeyPressed) of
					'W': begin
						if GameWorldLoad('.SZT', World.Info.Name) then begin
							ReturnBoardId := World.Info.CurrentBoard;
							returningFromGame := true;
							runTitle := true;
						end;
					end;
					'P': begin
						if World.Info.IsSave and not DebugEnabled then begin
							runPlay := WorldLoad(World.Info.Name, '.SZT', false);
							ReturnBoardId := World.Info.CurrentBoard;
						end else begin
							runPlay := true;
						end;
						runTitle := runPlay;
					end;
					'R': begin
						if GameWorldLoad('.SAV', SavedGameFileName) then begin
							VideoInstall(40, Blue);
							ReturnBoardId := World.Info.CurrentBoard;
							BoardChange(ReturnBoardId);
							runPlay := true;
							GamePlayStartRequested := true;
						end;
					end;
					'I': begin
						runTitle := true;
					end;
					'Q', KEY_ESCAPE: begin
						GameTitleExitRequested := PromptYesNo('Quit ZZT?  ', true, $4F);
					end;
					'O': begin
						VideoClear(Black);
						UnCrunch(
							WorldFileMenuScrPtrs[0]^,
							VideoTextPointer^,
							WorldFileMenuScrLens[0]
						);
						InputReadWaitKey;
					end;
					'H': begin
						HighScoresLoad;
						HighScoresDisplay(1);
					end;
					'|': begin
						GameDebugPrompt;
					end;
					'E': if EditorEnabled then begin
						EditorLoop;
						ReturnBoardId := World.Info.CurrentBoard;
						returningFromGame := true;
					end;
				end;
			end;
			if runTitle then begin
				VideoInstall(40, Blue);
				GameStateElement := E_MONITOR;
				GamePaused := false;
				GamePlayLoop(true);
				returningFromGame := true;
			end;
			if runPlay or GamePlayStartRequested then begin
				GameStateElement := E_PLAYER;
				GamePaused := true;
				if (not runTitle) and (not GamePlayStartRequested) then begin
					VideoInstall(40, Blue);
				end;
				GamePlayStartRequested := false;
				GamePlayLoop(false);
				returningFromGame := true;
			end;
		until GameTitleExitRequested <> false;
	end;

begin
end.
