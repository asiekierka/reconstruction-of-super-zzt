{
	BIN2PAS - binary -> Pascal code converter

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

program Bin2Pas;
uses Dos;

function FilenameToUnitName(s: string; asField: boolean): string;
	var
		pos: integer;
	label HasSplitFilename;
	label HasSplitBasename;
	begin
		for pos := Length(s) downto 1 do begin
			if s[pos] = '\' then begin
				s := Copy(s, pos + 1, Length(s) - pos);
				goto HasSplitFilename;
			end;
		end;

	HasSplitFilename:
		for pos := 1 to Length(s) do begin
			if s[pos] = '.' then begin
				if asField then
					s := Copy(s, 1, pos - 1) + Copy(s, pos + 1, Length(s) - pos)
				else
					s := Copy(s, 1, pos - 1);
				goto HasSplitBasename;
			end;
		end;

	HasSplitBasename:
		for pos := 1 to Length(s) do begin
			s[pos] := UpCase(s[pos]);
		end;

		FilenameToUnitName := s;
	end;

var
	inFile: file;
	outFile: text;
	unitName, fieldName: string;
	byteCount: word;
	bytePos: word;
	byteData: array[0 .. 511] of byte;

begin
	Writeln('BIN2PAS - binary -> Pascal code converter');
	Writeln('Copyright (c) 2020 Adrian Siekierka');
	Writeln;
	if (ParamCount < 2) then begin
		Writeln('Usage: BIN2PAS file.bin file.pas [field_name]');
		Exit;
	end;

	Assign(inFile, ParamStr(1));
	Reset(inFile, 1);
	Assign(outFile, ParamStr(2));
	Rewrite(outFile);
	byteCount := FileSize(inFile);

	unitName := FilenameToUnitName(ParamStr(2), false);
	if ParamCount >= 3 then
		fieldName := ParamStr(3)
	else
		fieldName := FilenameToUnitName(ParamStr(1), true);

	Writeln(outFile, 'unit ' + unitName + ';');
	Writeln(outFile);
	Writeln(outFile, 'interface');
	Writeln(outFile, #9'const');
	Write(outFile, #9#9 + fieldName + 'Size = ');
	Write(outFile, byteCount);
	Writeln(outFile, ';');
	Write(outFile, #9#9 + fieldName + 'Data: array[0 .. ');
	Write(outFile, byteCount - 1);
	Write(outFile, '] of byte = (');

	for bytePos := 0 to (byteCount - 1) do begin
		{ add comma after previous number }
		if (bytePos > 0) then
			Write(outFile, ', ');

		{ add new line }
		if ((bytePos and 15) = 0) then begin
			Writeln(outFile);
			Write(outFile, #9#9#9);
		end;

		{ fill buffer }
		if ((bytePos and $1FF) = 0) then begin
{$I-}
			BlockRead(inFile, byteData, 512);
{$I+}
			if IOResult <> 0 then begin end;
		end;

		Write(outFile, byteData[bytePos and $1FF]);
	end;

	Writeln(outFile);
	Writeln(outFile, #9#9');');
	Writeln(outFile);
	Writeln(outFile, 'implementation');
	Writeln(outFile, 'end.');

	Close(inFile);
	Close(outFile);

	Writeln('Wrote ', unitName, ' (', byteCount, ' bytes).');
end.

