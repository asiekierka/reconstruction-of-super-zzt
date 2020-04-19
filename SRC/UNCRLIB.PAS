{
	A permissively licensed reimplementation of the UNCRUNCH routine for
	decompressing TheDraw crunched images, adapted from CSIPACK.

	This version is written with clarity and documentation in mind; it is
	definitely slower than the official assembly variant.

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

unit Uncrlib;

interface
	procedure UnCrunch(var src, dest; srcLength: integer);

implementation
const
	SCREEN_WIDTH_BYTES = 160;

procedure UnCrunch(var src, dest; srcLength: integer);
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
	end;

begin
end.
