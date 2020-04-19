{
	CSIUnit - unit for (de)compressing TheDraw CSI files.

	Copyright (c) 2020 Adrian Siekierka

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

unit CSIUnit;

interface
	function CSICrunchScreen(var src, dest; srcLength: word): word;
	function CSIUnCrunchScreen(var src, dest; srcLength: word): word;

implementation
const
	SCREEN_WIDTH = 80;
	SCREEN_WIDTH_BYTES = SCREEN_WIDTH * 2;
	SCREEN_HEIGHT = 25;
	SCREEN_SIZE_BYTES = SCREEN_WIDTH_BYTES * SCREEN_HEIGHT;

function CSICrunchScreen(var src, dest; srcLength: word): word;
	type
		ByteA = array[0 .. MaxInt] of byte;
	var
		lineMaxs: array[0 .. (SCREEN_HEIGHT-1)] of integer;
		srcPos, destPos: word;
		currChar, currColor: byte;
		destColor: integer;
		destChar: integer;
		destCount: integer;
		ix, iy: integer;
	procedure WriteByte(v: byte);
		begin
			ByteA(dest)[destPos] := v;
			Inc(destPos);
		end;
	procedure ClearWriteChar;
		var
			i: integer;
		begin
			if (destCount >= 1) then begin
				if (destChar = $20) and (destCount > 2) then begin
					{ repeat spaces }
					WriteByte($19);
					WriteByte(destCount - 1);
				end else if (destChar < $20) or (destCount > 3) then begin
					{ repeat char N times }
					WriteByte($1A);
					WriteByte(destCount - 1);
					WriteByte(destChar);
				end else begin
					{ write char as-is ($20-$FF) }
					for i := 1 to destCount do begin
						WriteByte(destChar);
					end;
				end;
			end;
			destCount := 0;
		end;
	procedure WriteColorChange(from: integer; color: integer);
		begin
			{ change FG }
			if (from = -1) or ((from and $0F) <> (color and $0F)) then begin
				ClearWriteChar;
				WriteByte(color and $0F);
			end;
			{ change BG }
			if (from = -1) or ((from and $70) <> (color and $70)) then begin
				ClearWriteChar;
				WriteByte(((color shr 4) and $07) or $10);
			end;
			{ change blink }
			if (from <> -1) and ((from and $80) <> (color and $80)) then begin
				ClearWriteChar;
				WriteByte($1B);
			end;
		end;
	label LLCalcLineFinished;
	begin
		{ calculate line lengths }
		iy := 0;
		repeat
			lineMaxs[iy] := -1;
			for ix := (SCREEN_WIDTH - 1) downto 0 do begin
				currChar := ByteA(src)[(iy * SCREEN_WIDTH + ix) * 2];
				currColor := ByteA(src)[(iy * SCREEN_WIDTH + ix) * 2 + 1];
				if ((currChar <> $00) and (currChar <> $20)) or ((currColor and $70) <> $00) then begin
					lineMaxs[iy] := ix;
					goto LLCalcLineFinished;
				end;
			end;
	LLCalcLineFinished:
			Inc(iy);
		until iy = SCREEN_HEIGHT;

		{ encode }
		srcPos := 0;
		destPos := 0;
		destColor := -1;
		destChar := -1;
		destCount := 0;
		for iy := 0 to (SCREEN_HEIGHT - 1) do begin
			for ix := 0 to lineMaxs[iy] do begin
				currChar := ByteA(src)[srcPos + (ix shl 1)];
				currColor := ByteA(src)[srcPos + (ix shl 1) + 1];

				WriteColorChange(destColor, currColor);
				destColor := currColor;

				if currChar <> destChar then begin
					ClearWriteChar;
					destChar := currChar;
					destCount := 1;
				end else begin
					Inc(destCount);
					if (destCount >= 256) then
						ClearWriteChar;
				end;
			end;
			ClearWriteChar;
			WriteByte($18); { skip line }
			srcPos := srcPos + SCREEN_WIDTH_BYTES;
		end;

		CSICrunchScreen := destPos;
	end;

function CSIUnCrunchScreen(var src, dest; srcLength: word): word;
	type
		ByteA = array[0 .. MaxInt] of byte;
	var
		srcPos, destPos, destPosLine: word;
		cmd, color, count: byte;
	begin
		srcPos := 0;
		destPos := 0;
		destPosLine := 0;
		color := 0;
		while srcPos < srcLength do begin
			cmd := ByteA(src)[srcPos];
			Inc(srcPos);
			if cmd >= $20 then begin
				{ put char }
				ByteA(dest)[destPos] := cmd;
				Inc(destPos);
				ByteA(dest)[destPos] := color;
				Inc(destPos);
				Inc(destPosLine);
			end else if cmd = $1B then begin
				{ toggle blink }
				color := color xor $80
			end else if cmd = $1A then begin
				{ repeat char }
				count := ByteA(src)[srcPos];
				Inc(srcPos);
				cmd := ByteA(src)[srcPos];
				Inc(srcPos);
				repeat
					ByteA(dest)[destPos] := cmd;
					Inc(destPos);
					ByteA(dest)[destPos] := color;
					Inc(destPos);
					Dec(count);
					Inc(destPosLine);
				until count = $FF;
			end else if cmd = $19 then begin
				{ repeat space }
				count := ByteA(src)[srcPos];
				Inc(srcPos);
				repeat
					ByteA(dest)[destPos] := $20;
					Inc(destPos);
					ByteA(dest)[destPos] := color;
					Inc(destPos);
					Dec(count);
					Inc(destPosLine);
				until count = $FF;
			end else if cmd = $18 then begin
				{ next line }
				if destPosLine < (SCREEN_WIDTH_BYTES shr 1) then begin
					destPosLine := (SCREEN_WIDTH_BYTES shr 1) - destPosLine;
					repeat
						ByteA(dest)[destPos] := $20;
						Inc(destPos);
						ByteA(dest)[destPos] := $00;
						Inc(destPos);
						Dec(destPosLine);
					until destPosLine = 0;
				end;
				destPosLine := 0;
			end else if cmd >= $10 then begin
				{ set bg color }
				color := (color and $8F) or (cmd shl 4);
			end else if cmd >= $00 then begin
				{ set fg color }
				color := (color and $F0) or cmd;
			end;
		end;
		CSIUnCrunchScreen := destPos;
	end;

begin
end.
