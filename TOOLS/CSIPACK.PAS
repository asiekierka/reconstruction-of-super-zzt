{
	CSIPack - frontend for (de)compressing TheDraw CSI files.

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

program CSIPack;
uses CSIUnit, Dos;

const
	SCREEN_SIZE_BYTES = (80 * 25 * 2);
type
	TOutBuffer = array[0 .. (16384 - 1)] of byte; { should be enough space }

procedure CrunchFile;
	var
		inFile, outFile: file;
		outSize: word;
		inBuffer: ^TOutBuffer;
		outBuffer: ^TOutBuffer;
	begin
		Assign(inFile, ParamStr(2));
		Reset(inFile, 1);
		Assign(outFile, ParamStr(3));
		Rewrite(outFile, 1);

		New(inBuffer);
		New(outBuffer);

		BlockRead(inFile, inBuffer^, SCREEN_SIZE_BYTES);
		outSize := CSICrunchScreen(inBuffer^, outBuffer^, SCREEN_SIZE_BYTES);
		BlockWrite(outFile, outBuffer^, outSize);

		Dispose(inBuffer);
		Dispose(outBuffer);

		Close(inFile);
		Close(outFile);

		Writeln('Crunched ', SCREEN_SIZE_BYTES, ' -> ', outSize, ' bytes!');
	end;

procedure UncrunchFile;
	var
		inFile, outFile: file;
		inSize, outSize: word;
		inBuffer: ^TOutBuffer;
		outBuffer: ^TOutBuffer;
	begin
		Assign(inFile, ParamStr(2));
		Reset(inFile, 1);
		Assign(outFile, ParamStr(3));
		Rewrite(outFile, 1);

		inSize := FileSize(inFile);
		GetMem(inBuffer, inSize);
		New(outBuffer);

		BlockRead(inFile, inBuffer^, inSize);
		outSize := CSIUnCrunchScreen(inBuffer^, outBuffer^, inSize);
		BlockWrite(outFile, outBuffer^, outSize);

		Dispose(inBuffer);
		Dispose(outBuffer);

		Close(inFile);
		Close(outFile);

		Writeln('Uncrunched ', inSize, ' -> ', outSize, ' bytes!');
	end;

begin
	Writeln('CSIPACK - CSI screen image packing/unpacking tool');
	Writeln('Copyright (c) 2020 Adrian Siekierka');
	Writeln;
	if (ParamCount >= 3) and (ParamStr(1) = '/C') then
		CrunchFile
	else if (ParamCount >= 3) and (ParamStr(1) = '/U') then
		UncrunchFile
	else begin
		Writeln('Usage: ');
		Writeln('  - Crunch: CSIPACK /C file.bin file.csi');
		Writeln('  - Uncrunch: CSIPACK /U file.csi file.bin');
	end;
end.

