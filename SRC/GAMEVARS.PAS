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

unit GameVars;

interface
	const
		MAX_STAT = 128;
		MAX_ELEMENT = 79;
		MAX_FLAG = 16;
		MAX_BOARD = 32;
		BOARD_WIDTH = 96;
		BOARD_HEIGHT = 80;
		BOARD_DRAW_X = 14;
		BOARD_DRAW_Y = 2;
		BOARD_DRAW_WIDTH = 24;
		BOARD_DRAW_HEIGHT = 20;
		BOARD_DRAW_OX_MIN = 1;
		BOARD_DRAW_OX_MAX = BOARD_WIDTH - BOARD_DRAW_WIDTH + 1;
		BOARD_DRAW_OY_MIN = 1;
		BOARD_DRAW_OY_MAX = BOARD_HEIGHT - BOARD_DRAW_HEIGHT + 1;
		WORLD_FILE_HEADER_SIZE = 1024;
		WORLD_FILE_DESC_COUNT = 3;
		TRANSITION_TABLE_COUNT = 480;
		HIGH_SCORE_COUNT = 30;
		TORCH_DX = 8;
		TORCH_DY = 8;
		TORCH_DIST_SQR = 64 { 8 * 8 };
	type
		TSmallString = string[60];
		TCoord = record
			X: integer;
			Y: integer;
		end;
		TTile = record
			Element: byte;
			Color: byte;
		end;
		TElementDrawProc = procedure(x, y: integer; var ch: byte);
		TElementTickProc = procedure(statId: integer);
		TElementTouchProc = procedure(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
		TElementDef = record
			Character: char;
			Color: byte;
			Destructible: boolean;
			Pushable: boolean;
			PlaceableOnTop: boolean;
			Walkable: boolean;
			HasDrawProc: boolean;
			DrawProc: TElementDrawProc;
			Cycle: integer;
			TickProc: TElementTickProc;
			TouchProc: TElementTouchProc;
			EditorCategory: integer;
			EditorShortcut: char;
			Name: string[20];
			CategoryName: string[20];
			Param1Name: string[20];
			Param2Name: string[20];
			ParamBulletTypeName: string[20];
			ParamBoardName: string[20];
			ParamDirName: string[20];
			ParamTextName: string[20];
			ScoreValue: integer;
		end;
		TStat = record
			X, Y: byte;
			StepX, StepY: integer;
			Cycle: integer;
			P1, P2, P3: byte;
			Follower: integer;
			Leader: integer;
			Under: TTile;
			Data: ^string;
			DataPos: integer;
			DataLen: integer;
		end;
		TRleTile = record
			Count: byte;
			Tile: TTile;
		end;
		TBoardInfo = record
			MaxShots: byte;
			NeighborBoards: array[0 .. 3] of byte;
			ReenterWhenZapped: boolean;
			StartPlayerX: byte;
			StartPlayerY: byte;
			DrawXOffset: integer;
			DrawYOffset: integer;
			TimeLimitSec: integer;
			unk1: array[14 .. 27] of byte;
		end;
		TWorldInfo = record
			Ammo: integer;
			Gems: integer;
			Keys: array [1..7] of boolean;
			Health: integer;
			CurrentBoard: integer;
			unk1: integer;
			EnergizerTicks: integer;
			unk2: integer;
			Score: integer;
			Name: string[20];
			Flags: array[1 .. MAX_FLAG] of string[20];
			BoardTimeSec: integer;
			BoardTimeHsec: integer;
			IsSave: boolean;
			StonesOfPower: integer;
			unk3: array[387 .. 398] of byte;
		end;
		TEditorStatSetting = record
			P1, P2, P3: byte;
			StepX, StepY: integer;
		end;
		TBoard = record
			Name: TSmallString;
			Tiles: array[0 .. BOARD_WIDTH + 1] of array[0 .. BOARD_HEIGHT + 1] of TTile;
			StatCount: integer;
			Stats: array[0 .. MAX_STAT + 1] of TStat;
			Info: TBoardInfo;
		end;
		TWorld = record
			BoardCount: integer;
			BoardData: array[0 .. MAX_BOARD] of pointer;
			BoardLen: array[0 .. MAX_BOARD] of integer;
			Info: TWorldInfo;
			EditorStatSettings: array[0 .. MAX_ELEMENT] of TEditorStatSetting;
		end;
		THighScoreEntry = record
			Name: string[60];
			Score: integer;
		end;
		THighScoreList = array[1 .. HIGH_SCORE_COUNT] of THighScoreEntry;
		TIoTmpBuf = array[0 .. 19999] of byte;
	var
		ForestSoundTableIdx: integer;
		TransitionTable: array[1 .. TRANSITION_TABLE_COUNT] of TCoord;

		LoadedGameFileName: TSmallString;
		SavedGameFileName: TSmallString;
		SavedBoardFileName: TSmallString;
		StartupWorldFileName: TSmallString;

		Board: TBoard;
		World: TWorld;
		MessageAmmoNotShown: boolean;
		MessageOutOfAmmoNotShown: boolean;
		MessageNoShootingNotShown: boolean;
		MessageForestNotShown: boolean;
		MessageFakeNotShown: boolean;
		MessageGemNotShown: boolean;
		MessageEnergizerNotShown: boolean;
		unkVar_7c12: array[0 .. 15] of byte;

		MessageLine1: TSmallString;
		MessageLine2: TSmallString;

		GameTitleExitRequested: boolean;
		GamePlayExitRequested: boolean;
		GamePlayStartRequested: boolean;
		GameStateElement: integer;
		ReturnBoardId: integer;

		TickSpeed: byte;

		IoTmpBuf: ^TIoTmpBuf;

		ElementDefs: array[0 .. MAX_ELEMENT] of TElementDef;
		EditorPatternCount: integer;
		EditorPatterns: array[1 .. 10] of byte;

		TickTimeDuration: integer;
		CurrentTick: integer;
		CurrentStatTicked: integer;
		GamePaused: boolean;
		TickTimeCounter: integer;

		ForceDarknessOff: boolean;
		InitialTextAttr: byte;

		OopChar: char;
		OopWord: string[20];
		OopValue: integer;

		DebugEnabled: boolean;

		HighScoreList: THighScoreList;

		EditorEnabled: boolean;
		IsRegistered: boolean;
		ResetConfig: boolean;
		JustStarted: boolean;

		WorldFileDescCount: integer;
		WorldFileDescKeys: array[1 .. WORLD_FILE_DESC_COUNT] of TSmallString;
		WorldFileDescValues: array[1 .. WORLD_FILE_DESC_COUNT] of TSmallString;

		WorldFileMenuScrPtrs: array[-1 .. WORLD_FILE_DESC_COUNT] of pointer;
		WorldFileMenuScrLens: array[-1 .. WORLD_FILE_DESC_COUNT] of word;
		MenuScrPointer: pointer;
		MenuScrLen: word;
	const
		E_EMPTY = 0;
		E_BOARD_EDGE = 1;
		E_MESSAGE_TIMER = 2;
		E_MONITOR = 3;
		E_PLAYER = 4;
		E_AMMO = 5;
		E_GEM = 7;
		E_KEY = 8;
		E_DOOR = 9;
		E_SCROLL = 10;
		E_PASSAGE = 11;
		E_DUPLICATOR = 12;
		E_BOMB = 13;
		E_ENERGIZER = 14;
		E_CONVEYOR_CW = 16;
		E_CONVEYOR_CCW = 17;
		E_LAVA = 19;
		E_FOREST = 20;
		E_SOLID = 21;
		E_NORMAL = 22;
		E_BREAKABLE = 23;
		E_BOULDER = 24;
		E_SLIDER_NS = 25;
		E_SLIDER_EW = 26;
		E_FAKE = 27;
		E_INVISIBLE = 28;
		E_BLINK_WALL = 29;
		E_TRANSPORTER = 30;
		E_LINE = 31;
		E_RICOCHET = 32;
		E_BEAR = 34;
		E_RUFFIAN = 35;
		E_OBJECT = 36;
		E_SLIME = 37;
		E_SPINNING_GUN = 39;
		E_PUSHER = 40;
		E_LION = 41;
		E_TIGER = 42;
		E_CENTIPEDE_HEAD = 44;
		E_CENTIPEDE_SEGMENT = 45;
		E_FLOOR = 47;
		E_WATER_N = 48;
		E_WATER_S = 49;
		E_WATER_W = 50;
		E_WATER_E = 51;
		E_ROTON = 59;
		E_DRAGON_PUP = 60;
		E_PAIRER = 61;
		E_SPIDER = 62;
		E_WEB = 63;
		E_STONE = 64;
		E_BULLET = 69;
		E_BLINK_RAY_EW = 70;
		E_BLINK_RAY_NS = 71;
		E_STAR = 72;
		{}
		E_TEXT_MIN = 73;
		E_TEXT_BLUE = (E_TEXT_MIN);
		E_TEXT_GREEN = (E_TEXT_MIN + 1);
		E_TEXT_CYAN = (E_TEXT_MIN + 2);
		E_TEXT_RED = (E_TEXT_MIN + 3);
		E_TEXT_PURPLE = (E_TEXT_MIN + 4);
		E_TEXT_YELLOW = (E_TEXT_MIN + 5);
		E_TEXT_WHITE = (E_TEXT_MIN + 6);
		{}
		CATEGORY_ITEM = 1;
		CATEGORY_CREATURE = 2;
		CATEGORY_TERRAIN = 3;
		CATEGORY_UGLIES = 4;
		CATEGORY_TERRAIN2 = 5;
		{}
		COLOR_SPECIAL_MIN = $F0;
		COLOR_CHOICE_ON_BLACK = $FF;
		COLOR_WHITE_ON_CHOICE = $FE;
		COLOR_CHOICE_ON_CHOICE = $FD;
		{}
		SHOT_SOURCE_PLAYER = 0;
		SHOT_SOURCE_ENEMY = 1;

implementation

begin
end.
