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

{$F+}
{$I-}
unit Elements;

interface
	uses GameVars;
	procedure ElementMove(oldX, oldY, newX, newY: integer);
	procedure ElementPushablePush(x, y: integer; deltaX, deltaY: integer);
	procedure DrawPlayerSurroundings(x, y: integer; bombPhase: integer);
	procedure GamePromptEndPlay;
	procedure ResetMessageNotShownFlags;
	procedure InitElementsEditor;
	procedure InitElementsGame;
	procedure InitEditorStatSettings;

implementation
uses Crt, Video, Sounds, Input, TxtWind, Editor, Oop, Game;

const
	ForestSoundTable: array[0 .. 7] of byte = ($45, $40, $47, $50, $46, $41, $48, $51);
	TransporterNSChars: string = '^~^-v_v-';
	TransporterEWChars: string = '(<('#179')>)'#179;
	StarAnimChars: string = #179'/'#196'\';

procedure ElementDefaultTick(statId: integer);
	begin
	end;

procedure ElementDefaultTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
	end;

procedure ElementDefaultDraw(x, y: integer; var ch: byte);
	begin
		ch := Ord('?');
	end;

procedure ElementMessageTimerTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			case X of
				0: begin
					VideoWriteText(26 - (Length(MessageLine1) div 2), 23, $19 + (P2 mod 7), ' '+MessageLine1+' ');
					VideoWriteText(26 - (Length(MessageLine2) div 2), 24, $19 + (P2 mod 7), ' '+MessageLine2+' ');
					P2 := P2 - 1;
					if P2 <= 0 then begin
						RemoveStat(statId);
						CurrentStatTicked := CurrentStatTicked - 1;
						MessageLine1 := '';
						MessageLine2 := '';
						ClearDisplayMessage;
					end;
				end;
			end;
		end;
	end;

procedure ElementDamagingTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		BoardAttack(sourceStatId, x, y);
	end;

procedure ElementLionTick(statId: integer);
	var
		deltaX, deltaY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 < Random(10) then
				CalcDirectionRnd(deltaX, deltaY)
			else
				CalcDirectionSeek(X, Y, deltaX, deltaY);

			if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then begin
				MoveStat(statId, X + deltaX, Y + deltaY);
			end else if Board.Tiles[X + deltaX][Y + deltaY].Element = E_PLAYER then begin
				BoardAttack(statId, X + deltaX, Y + deltaY)
			end;
		end;
	end;

procedure ElementTigerTick(statId: integer);
	var
		shot: boolean;
		element: byte;
	begin
		with Board.Stats[statId] do begin
			element := E_BULLET;
			if P2 >= $80 then
				element := E_STAR;

			if (Random(10) * 3) <= (P2 mod $80) then begin
				if Difference(X, Board.Stats[0].X) <= 2 then begin
					shot := BoardShoot(element, X, Y, 0, Signum(Board.Stats[0].Y - Y), SHOT_SOURCE_ENEMY);
				end else begin
					shot := false;
				end;

				if not shot then begin
					if Difference(Y, Board.Stats[0].Y) <= 2 then begin
						shot := BoardShoot(element, X, Y, Signum(Board.Stats[0].X - X), 0, SHOT_SOURCE_ENEMY);
					end;
				end;
			end;

			ElementLionTick(statId);
		end;
	end;

procedure ElementRotonTick(statId: integer);
	var
		tmp: integer;
	begin
		with Board.Stats[statId] do begin
			Dec(P3);
			if (P3 < (-P2 * 10)) then
				P3 := P2 * 10 + Random(10);

			CalcDirectionSeek(X, Y, StepX, StepY);
			if (P1 <= Random(10)) then begin
				tmp := StepX;
				StepX := -Signum(P2) * StepY;
				StepY := Signum(P2) * tmp;
			end;

			if ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then begin
				MoveStat(statId, X + StepX, Y + StepY);
			end else if Board.Tiles[X + StepX][Y + StepY].Element = E_PLAYER then begin
				BoardAttack(statId, X + StepX, Y + StepY)
			end;
		end;
	end;

procedure ElementDragonPupTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementDragonPupDraw(x, y: integer; var ch: byte);
	begin
		case (CurrentTick and 3) of
			0, 2: ch := 148;
			1: ch := 162;
			3: ch := 149;
		end;
	end;


procedure ElementPairerTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
		end;
	end;

procedure ElementSpiderTick(statId: integer);
	var
		deltaX, deltaY, i: integer;
	function SpiderTryMove(dx, dy: integer): boolean;
		begin
			with Board.Stats[statId] do begin
				SpiderTryMove := false;

				if Board.Tiles[X + dx][Y + dy].Element = E_WEB then begin
					MoveStat(statId, X + dx, Y + dy);
					SpiderTryMove := true;
				end else if Board.Tiles[X + dx][Y + dy].Element = E_PLAYER then begin
					BoardAttack(statId, X + dx, Y + dy);
					SpiderTryMove := true;
				end;
			end;
		end;
	begin
		with Board.Stats[statId] do begin
			if P1 > Random(10) then
				CalcDirectionSeek(X, Y, deltaX, deltaY)
			else
				CalcDirectionRnd(deltaX, deltaY);

			if not SpiderTryMove(deltaX, deltaY) then begin
				i := Random(2) * 2 - 1;
				if not SpiderTryMove(deltaY * i, deltaX * i) then begin
					if not SpiderTryMove(-deltaY * i, -deltaX * i) then begin
						if SpiderTryMove(-deltaX, -deltaY) then begin end;
					end;
				end;
			end;
		end;
	end;

procedure ElementRuffianTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if (StepX = 0) and (StepY = 0) then begin
				if (P2 + 8) <= Random(17) then begin
					if P1 >= Random(9) then
						CalcDirectionSeek(X, Y, StepX, StepY)
					else
						CalcDirectionRnd(StepX, StepY);
				end;
			end else begin
				if ((Y = Board.Stats[0].Y) or (X = Board.Stats[0].X)) and (Random(9) <= P1) then begin
					CalcDirectionSeek(X, Y, StepX, StepY);
				end;

				with Board.Tiles[X + StepX][Y + StepY] do begin
					if Element = E_PLAYER then begin
						BoardAttack(statId, X + StepX, Y + StepY)
					end else if ElementDefs[Element].Walkable then begin
						MoveStat(statId, X + StepX, Y + StepY);
						if (P2 + 8) <= Random(17) then begin
							StepX := 0;
							StepY := 0;
						end;
					end else begin
						StepX := 0;
						StepY := 0;
					end;
				end;

			end;
		end;
	end;

procedure ElementBearTick(statId: integer);
	var
		deltaX, deltaY: integer;
	label Movement;
	begin
		with Board.Stats[statId] do begin
			if X <> Board.Stats[0].X then
				if Difference(Y, Board.Stats[0].Y) <= (8 - P1) then begin
					deltaX := Signum(Board.Stats[0].X - X);
					deltaY := 0;
					goto Movement;
				end;

			if Difference(X, Board.Stats[0].X) <= (8 - P1) then begin
				deltaY := Signum(Board.Stats[0].Y - Y);
				deltaX := 0;
			end else begin
				deltaX := 0;
				deltaY := 0;
			end;

		Movement:
			with Board.Tiles[X + deltaX][Y + deltaY] do begin
				if ElementDefs[Element].Walkable then begin
					MoveStat(statId, X + deltaX, Y + deltaY);
				end else if (Element = E_PLAYER) or (Element = E_BREAKABLE) then begin
					BoardAttack(statId, X + deltaX, Y + deltaY)
				end;
			end;

		end;
	end;

procedure ElementCentipedeHeadTick(statId: integer);
	var
		ix, iy: integer;
		tx, ty: integer;
		tmp: integer;
	begin
		with Board.Stats[statId] do begin
			if (X = Board.Stats[0].X) and (Random(10) < P1) then begin
				StepY := Signum(Board.Stats[0].Y - Y);
				StepX := 0;
			end else if (Y = Board.Stats[0].Y) and (Random(10) < P1) then begin
				StepX := Signum(Board.Stats[0].X - X);
				StepY := 0;
			end else if ((Random(10) * 4) < P2) or ((StepX = 0) and (StepY = 0)) then begin
				CalcDirectionRnd(StepX, StepY);
			end;

			if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable
				and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
			begin
				ix := StepX;
				iy := StepY;
				tmp := ((Random(2) * 2) - 1) * StepY;
				StepY := ((Random(2) * 2) - 1) * StepX;
				StepX := tmp;
				if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable
					and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
				begin
					StepX := -StepX;
					StepY := -StepY;
					if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable
						and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
					begin
						if ElementDefs[Board.Tiles[X - ix][Y - iy].Element].Walkable
							or (Board.Tiles[X - ix][Y - iy].Element = E_PLAYER) then
						begin
							StepX := -ix;
							StepY := -iy;
						end else begin
							StepX := 0;
							StepY := 0;
						end;
					end;
				end;
			end;

			if (StepX = 0) and (StepY = 0) then begin
				Board.Tiles[X][Y].Element := E_CENTIPEDE_SEGMENT;
				Leader := -1;
				while Board.Stats[statId].Follower > 0 do begin
					tmp := Board.Stats[statId].Follower;
					Board.Stats[statId].Follower := Board.Stats[statId].Leader;
					Board.Stats[statId].Leader := tmp;
					statId := tmp;
				end;
				Board.Stats[statId].Follower := Board.Stats[statId].Leader;
				Board.Stats[statId].Leader := -1;
				Board.Tiles[Board.Stats[statId].X][Board.Stats[statId].Y].Element := E_CENTIPEDE_HEAD;
			end else if Board.Tiles[X + StepX][Y + StepY].Element = E_PLAYER then begin
				if Follower > 0 then begin
					Board.Tiles[Board.Stats[Follower].X][Board.Stats[Follower].Y].Element := E_CENTIPEDE_HEAD;
					Board.Stats[Follower].StepX := StepX;
					Board.Stats[Follower].StepY := StepY;
					BoardDrawTile(Board.Stats[Follower].X, Board.Stats[Follower].Y);
				end;
				BoardAttack(statId, X + StepX, Y + StepY);
			end else begin
				MoveStat(statId, X + StepX, Y + StepY);

				repeat
					with Board.Stats[statId] do begin
						tx := X - StepX;
						ty := Y - StepY;
						ix := StepX;
						iy := StepY;
						if Follower < 0 then begin
							if (Board.Tiles[tx - ix][ty - iy].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx - ix, ty - iy)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx - ix, ty - iy)
							end else if (Board.Tiles[tx - iy][ty - ix].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx - iy, ty - ix)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx - iy, ty - ix);
							end else if (Board.Tiles[tx + iy][ty + ix].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx + iy, ty + ix)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx + iy, ty + ix);
							end;
						end;

						if (Follower > 0)
							and (Board.Tiles[Board.Stats[Follower].X][Board.Stats[Follower].Y].Element = E_CENTIPEDE_SEGMENT)
						then begin
							Board.Stats[Follower].Leader := statId;
							Board.Stats[Follower].P1 := P1;
							Board.Stats[Follower].P2 := P2;
							Board.Stats[Follower].StepX := tx - Board.Stats[Follower].X;
							Board.Stats[Follower].StepY := ty - Board.Stats[Follower].Y;
							MoveStat(Follower, tx, ty);
						end;
						statId := Follower;
					end;
				until statId = -1;
			end;
		end;
	end;

procedure ElementCentipedeSegmentTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if Leader < 0 then begin
				if Leader < -1 then
					Board.Tiles[X][Y].Element := E_CENTIPEDE_HEAD
				else
					Leader := Leader - 1;
			end;
		end;
	end;

procedure ElementBulletTick(statId: integer);
	var
		ix, iy: integer;
		iStat: integer;
		iElem: byte;
		firstTry: boolean;
	label TryMove;
	begin
		with Board.Stats[statId] do begin
			firstTry := true;

		TryMove:
			ix := X + StepX;
			iy := Y + StepY;
			iElem := Board.Tiles[ix][iy].Element;

			if ElementDefs[iElem].Walkable or (iElem = E_LAVA) then begin
				MoveStat(statId, ix, iy);
				exit;
			end;

			if (iElem = E_RICOCHET) and firstTry then begin
				StepX := -StepX;
				StepY := -StepY;
				SoundQueue(1, #249#1);
				firstTry := false;
				goto TryMove;
				exit;
			end;

			if (iElem = E_BREAKABLE)
				or (ElementDefs[iElem].Destructible and ((iElem = E_PLAYER) or (P1 = 0))) then
			begin
				if ElementDefs[iElem].ScoreValue <> 0 then begin
					World.Info.Score := World.Info.Score + ElementDefs[iElem].ScoreValue;
					GameUpdateSidebar;
				end;
				BoardAttack(statId, ix, iy);
				BoardDrawTile(ix, iy);
				exit;
			end;

			if (Board.Tiles[X + StepY][Y + StepX].Element = E_RICOCHET) and firstTry then begin
				ix := StepX;
				StepX := -StepY;
				StepY := -ix;
				SoundQueue(1, #249#1);
				firstTry := false;
				goto TryMove;
				exit;
			end;

			if (Board.Tiles[X - StepY][Y - StepX].Element = E_RICOCHET) and firstTry then begin
				ix := StepX;
				StepX := StepY;
				StepY := ix;
				SoundQueue(1, #249#1);
				firstTry := false;
				goto TryMove;
				exit;
			end;

			RemoveStat(statId);
			CurrentStatTicked := CurrentStatTicked - 1;
			if (iElem = E_OBJECT) or (iElem = E_SCROLL) then begin
				iStat := GetStatIdAt(ix, iy);
				if OopSend(-iStat, 'SHOT', false) then begin end;
			end;
		end;
	end;

procedure ElementSpinningGunDraw(x, y: integer; var ch: byte);
	begin
		case CurrentTick mod 8 of
			0, 1: ch := 24;
			2, 3: ch := 26;
			4, 5: ch := 25;
		else ch := 27 end;
	end;

procedure ElementConnectedDraw(x, y: integer; elementType: byte; var tiles: TSmallString; var ch: byte);
	var
		i, v, shift: integer;
		currElement: byte;
	begin
		v := 1;
		shift := 1;
		for i := 0 to 3 do begin
			currElement := Board.Tiles[x + NeighborDeltaX[i]][y + NeighborDeltaY[i]].Element;
			if ElementDefs[currElement].Cycle >= 0 then begin
				currElement := Board.Stats[GetStatIdAt(x + NeighborDeltaX[i], y + NeighborDeltaY[i])]
					.Under.Element;
			end;
			if currElement in [E_BOARD_EDGE, elementType] then begin
				v := v + shift;
			end;
			shift := shift shl 1;
		end;
		ch := Ord(tiles[v]);
	end;

procedure ElementLineDraw(x, y: integer; var ch: byte);
	begin
		ElementConnectedDraw(x, y, E_LINE, LineChars, ch);
	end;

procedure ElementWebDraw(x, y: integer; var ch: byte);
	begin
		ElementConnectedDraw(x, y, E_WEB, WebChars, ch);
	end;

procedure ElementSpinningGunTick(statId: integer);
	var
		shot: boolean;
		deltaX, deltaY: integer;
		element: byte;
	begin
		with Board.Stats[statId] do begin
			BoardDrawTile(X, Y);

			element := E_BULLET;
			if P2 >= $80 then
				element := E_STAR;

			if Random(9) < (P2 mod $80) then begin
				if Random(9) <= P1 then begin
					if Difference(X, Board.Stats[0].X) <= 2 then begin
						shot := BoardShoot(element, X, Y, 0, Signum(Board.Stats[0].Y - Y), SHOT_SOURCE_ENEMY);
					end else begin
						shot := false;
					end;

					if not shot then begin
						if Difference(Y, Board.Stats[0].Y) <= 2 then begin
							shot := BoardShoot(element, X, Y, Signum(Board.Stats[0].X - X), 0, SHOT_SOURCE_ENEMY);
						end;
					end;
				end else begin
					CalcDirectionRnd(deltaX, deltaY);
					shot := BoardShoot(element, X, Y, deltaX, deltaY, SHOT_SOURCE_ENEMY);
				end;
			end;
		end;
	end;

procedure ElementConveyorTick(x, y: integer; direction: integer);
	var
		i: integer;
		iStat: integer;
		ix, iy: integer;
		canMove: boolean;
		tiles: array[0..7] of TTile;
		iMin, iMax: integer;
		tmpTile: TTile;
	begin
		if direction = 1 then begin
			iMin := 0;
			iMax := 8;
		end else begin
			iMin := 7;
			iMax := -1;
		end;

		canMove := true;
		i := iMin;
		repeat
			tiles[i] := Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]];
			with tiles[i] do begin
				if Element = E_EMPTY then
					canMove := true
				else if not ElementDefs[Element].Pushable then
					canMove := false;
			end;
			i := i + direction;
		until i = iMax;

		i := iMin;
		repeat
			with tiles[i] do begin
				if canMove then begin
					if ElementDefs[Element].Pushable then begin
						ix := x + DiagonalDeltaX[(i - direction + 8) mod 8];
						iy := y + DiagonalDeltaY[(i - direction + 8) mod 8];
						if ElementDefs[Element].Cycle > -1 then begin
							tmpTile := Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]];
							iStat := GetStatIdAt(x + DiagonalDeltaX[i], y + DiagonalDeltaY[i]);
							Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]] := tiles[i];
							Board.Tiles[ix][iy].Element := E_EMPTY;
							MoveStat(iStat, ix, iy);
							Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]] := tmpTile;
						end else begin
							Board.Tiles[ix][iy] := tiles[i];
							BoardDrawTile(ix, iy);
						end;
						if not ElementDefs[tiles[(i + direction + 8) mod 8].Element].Pushable then begin
							Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]].Element := E_EMPTY;
						end;
					end else begin
						canMove := false;
					end;
				end else if Element = E_EMPTY then
					canMove := true
				else if not ElementDefs[Element].Pushable then
					canMove := false;
			end;
			i := i + direction;
		until i = iMax;
	end;

procedure ElementConveyorCWDraw(x, y: integer; var ch: byte);
	begin
		case (CurrentTick div ElementDefs[E_CONVEYOR_CW].Cycle) mod 4 of
			0: ch := 179;
			1: ch := 47;
			2: ch := 196;
		else ch := 92 end;
	end;

procedure ElementConveyorCWTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			BoardDrawTile(X, Y);
			ElementConveyorTick(X, Y, 1);
		end;
	end;

procedure ElementConveyorCCWDraw(x, y: integer; var ch: byte);
	begin
		case (CurrentTick div ElementDefs[E_CONVEYOR_CCW].Cycle) mod 4 of
			3: ch := 179;
			2: ch := 47;
			1: ch := 196;
		else ch := 92 end;
	end;

procedure ElementConveyorCCWTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			BoardDrawTile(X, Y);
			ElementConveyorTick(X, Y, -1);
		end;
	end;

procedure ElementBombDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do
			if P1 <= 1 then
				ch := 11
			else
				ch := 48 + P1;
	end;

procedure ElementBombTick(statId: integer);
	var
		oldX, oldY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 > 0 then begin
				P1 := P1 - 1;
				BoardDrawTile(X, Y);

				if P1 = 1 then begin
					SoundQueue(1, #96#1#80#1#64#1#48#1#32#1#16#1);
					DrawPlayerSurroundings(X, Y, 1);
				end else if P1 = 0 then begin
					oldX := X;
					oldY := Y;
					RemoveStat(statId);
					DrawPlayerSurroundings(oldX, oldY, 2);
				end else begin
					if (P1 mod 2) = 0 then
						SoundQueue(1, #248#1)
					else
						SoundQueue(1, #245#1);
				end;
			end;
		end;
	end;

procedure ElementBombTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if P1 = 0 then begin
				P1 := 9;
				BoardDrawTile(X, Y);
				DisplayMessage(200, '', 'Bomb activated!');
				SoundQueue(4, #48#1#53#1#64#1#69#1#80#1);
			end else begin
				ElementPushablePush(X, Y, deltaX, deltaY);
			end;
		end;
	end;

procedure ElementTransporterMove(x, y, deltaX, deltaY: integer);
	var
		ix, iy: integer;
		newX, newY: integer;
		iStat: integer;
		finishSearch: boolean;
		isValidDest: boolean;
	begin
		with Board.Stats[GetStatIdAt(x + deltaX, y + deltaY)] do begin
			if (deltaX = StepX) and (deltaY = StepY) then begin
				ix := X;
				iy := Y;
				newX := -1;
				finishSearch := false;
				isValidDest := true;
				repeat
					ix := ix + deltaX;
					iy := iy + deltaY;
					with Board.Tiles[ix][iy] do begin
						if Element = E_BOARD_EDGE then
							finishSearch := true
						else if isValidDest then begin
							isValidDest := false;

							if not ElementDefs[Element].Walkable then
								ElementPushablePush(ix, iy, deltaX, deltaY);

							if ElementDefs[Element].Walkable then begin
								finishSearch := true;
								newX := ix;
								newY := iy;
							end else begin
								newX := -1
							end;
						end;
						if Element = E_TRANSPORTER then begin
							iStat := GetStatIdAt(ix, iy);
							if (Board.Stats[iStat].StepX = -deltaX) and (Board.Stats[iStat].StepY = -deltaY) then
								isValidDest := true;
						end;
					end;
				until finishSearch;
				if newX <> -1 then begin
					ElementMove(X - deltaX, Y - deltaY, newX, newY);
					SoundQueue(3, #48#1#66#1#52#1#70#1#56#1#74#1#64#1#82#1);
				end;
			end;
		end;
	end;

procedure ElementTransporterTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		ElementTransporterMove(x - deltaX, y - deltaY, deltaX, deltaY);
		deltaX := 0;
		deltaY := 0;
	end;

procedure ElementTransporterTick(statId: integer);
	begin
		with Board.Stats[statId] do
			BoardDrawTile(X, Y);
	end;

procedure ElementTransporterDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if StepX = 0 then
				ch := Ord(TransporterNSChars[StepY * 2 + 3 + (CurrentTick div Cycle) mod 4])
			else
				ch := Ord(TransporterEWChars[StepX * 2 + 3 + (CurrentTick div Cycle) mod 4]);
		end;
	end;

procedure ElementStarDraw(x, y: integer; var ch: byte);
	begin
		ch := Ord(StarAnimChars[(CurrentTick mod 4) + 1]);
		Board.Tiles[x][y].Color := Board.Tiles[x][y].Color + 1;
		if Board.Tiles[x][y].Color > 15 then
			Board.Tiles[x][y].Color := 9;
	end;

procedure ElementStarTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			P2 := P2 - 1;
			if P2 <= 0 then begin
				RemoveStat(statId);
			end else if (P2 mod 2) = 0 then begin
				CalcDirectionSeek(X, Y, StepX, StepY);
				with Board.Tiles[X + StepX][Y + StepY] do begin
					if (Element = E_PLAYER) or (Element = E_BREAKABLE) then begin
						BoardAttack(statId, X + StepX, Y + StepY);
					end else begin
						if not ElementDefs[Element].Walkable then
							ElementPushablePush(X + StepX, Y + StepY, StepX, StepY);

						if ElementDefs[Element].Walkable or (Element = E_LAVA) then
							MoveStat(statId, X + StepX, Y + StepY);
					end;
				end;
			end else begin
				BoardDrawTile(X, Y);
			end;
		end;
	end;

procedure ElementEnergizerTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		SoundQueue(9, #32#3#35#3#36#3#37#3#53#3#37#3#35#3#32#3
			+ #48#3#35#3#36#3#37#3#53#3#37#3#35#3#32#3
			+ #48#3#35#3#36#3#37#3#53#3#37#3#35#3#32#3
			+ #48#3#35#3#36#3#37#3#53#3#37#3#35#3#32#3
			+ #48#3#35#3#36#3#37#3#53#3#37#3#35#3#32#3
			+ #48#3#35#3#36#3#37#3#53#3#37#3#35#3#32#3
			+ #48#3#35#3#36#3#37#3#53#3#37#3#35#3#32#3);

		BoardRemoveTile(x, y);

		World.Info.EnergizerTicks := 75;
		GameUpdateSidebar;

		if MessageEnergizerNotShown then begin
			DisplayMessage(200, 'Shield:', 'You are invincible');
			MessageEnergizerNotShown := false;
		end;

		if OopSend(0, 'ALL:ENERGIZE', false) then begin end;
	end;

procedure ElementSlimeTick(statId: integer);
	var
		dir, color, changedTiles: integer;
		startX, startY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 < P2 then
				P1 := P1 + 1
			else begin
				color := Board.Tiles[X][Y].Color;
				P1 := 0;
				startX := X;
				startY := Y;
				changedTiles := 0;

				for dir := 0 to 3 do begin
					if ElementDefs[Board.Tiles[startX + NeighborDeltaX[dir]][startY + NeighborDeltaY[dir]].Element].Walkable then begin
						if changedTiles = 0 then begin
							MoveStat(statId, startX + NeighborDeltaX[dir], startY + NeighborDeltaY[dir]);
							Board.Tiles[startX][startY].Color := color;
							Board.Tiles[startX][startY].Element := E_BREAKABLE;
							BoardDrawTile(startX, startY);
						end else begin
							AddStat(startX + NeighborDeltaX[dir], startY + NeighborDeltaY[dir], E_SLIME, color,
								ElementDefs[E_SLIME].Cycle, StatTemplateDefault);
							Board.Stats[Board.StatCount].P2 := P2;
						end;

						changedTiles := changedTiles + 1;
					end;
				end;

				if changedTiles = 0 then begin
					RemoveStat(statId);
					Board.Tiles[startX][startY].Element := E_BREAKABLE;
					Board.Tiles[startX][startY].Color := color;
					BoardDrawTile(startX, startY);
				end;
			end;
		end;
	end;

procedure ElementSlimeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		color: integer;
	begin
		color := Board.Tiles[x][y].Color;
		DamageStat(GetStatIdAt(x, y));
		Board.Tiles[x][y].Element := E_BREAKABLE;
		Board.Tiles[x][y].Color := color;
		BoardDrawTile(x, y);
		SoundQueue(2, #32#1#35#1);
	end;

procedure ElementBlinkWallDraw(x, y: integer; var ch: byte);
	begin
		ch := 206;
	end;

procedure ElementBlinkWallTick(statId: integer);
	var
		ix, iy: integer;
		hitBoundary: boolean;
		playerStatId: integer;
		el: integer;
	begin
		with Board.Stats[statId] do begin
			if P3 = 0 then
				P3 := P1 + 1;
			if P3 = 1 then begin
				ix := X + StepX;
				iy := Y + StepY;

				if StepX <> 0 then
					el := E_BLINK_RAY_EW
				else
					el := E_BLINK_RAY_NS;

				while (Board.Tiles[ix][iy].Element = el)
					and (Board.Tiles[ix][iy].Color = Board.Tiles[X][Y].Color) do
				begin
					Board.Tiles[ix][iy].Element := E_EMPTY;
					BoardDrawTile(ix, iy);
					ix := ix + StepX;
					iy := iy + StepY;
					P3 := (P2) * 2 + 1;
				end;

				if ((X + StepX) = ix) and ((Y + StepY) = iy) then begin
					hitBoundary := false;
					repeat
						if (Board.Tiles[ix][iy].Element <> E_EMPTY) and (ElementDefs[Board.Tiles[ix][iy].Element].Destructible) then
							BoardDamageTile(ix, iy);

						if Board.Tiles[ix][iy].Element = E_PLAYER then begin
							playerStatId := GetStatIdAt(ix, iy);
							if StepX <> 0 then begin
								if Board.Tiles[ix][iy - 1].Element = E_EMPTY then
									MoveStat(playerStatId, ix, iy - 1)
								else if Board.Tiles[ix][iy + 1].Element = E_EMPTY then
									MoveStat(playerStatId, ix, iy + 1);
							end else begin
								if Board.Tiles[ix + 1][iy].Element = E_EMPTY then
									MoveStat(playerStatId, ix + 1, iy)
								else if Board.Tiles[ix - 1][iy].Element = E_EMPTY then
									MoveStat(playerStatId, ix + 1, iy);
							end;

							if Board.Tiles[ix][iy].Element = E_PLAYER then begin
								while World.Info.Health > 0 do
									DamageStat(playerStatId);
								hitBoundary := true;
							end;
						end;

						if Board.Tiles[ix][iy].Element = E_EMPTY then begin
							Board.Tiles[ix][iy].Element := el;
							Board.Tiles[ix][iy].Color := Board.Tiles[X][Y].Color;
							BoardDrawTile(ix, iy);
						end else begin
							hitBoundary := true;
						end;

						ix := ix + StepX;
						iy := iy + StepY;
					until hitBoundary;

					P3 := (P2 * 2) + 1;
				end;
			end else begin
				P3 := P3 - 1;
			end;
		end;
	end;

procedure ElementMove(oldX, oldY, newX, newY: integer);
	var
		statId: integer;
	begin
		statId := GetStatIdAt(oldX, oldY);

		if statId >= 0 then begin
			MoveStat(statId, newX, newY);
		end else begin
			Board.Tiles[newX][newY] := Board.Tiles[oldX][oldY];
			BoardDrawTile(newX, newY);
			BoardRemoveTile(oldX, oldY);
		end;
	end;

procedure ElementPushablePush(x, y: integer; deltaX, deltaY: integer);
	var
		unk1: integer;
		targetElem: integer;
	begin
		with Board.Tiles[x][y] do begin
			if ((Element = E_SLIDER_NS) and (deltaX = 0)) or ((Element = E_SLIDER_EW) and (deltaY = 0))
				or ElementDefs[Element].Pushable then
			begin
				if Board.Tiles[x + deltaX][y + deltaY].Element = E_TRANSPORTER then
					ElementTransporterMove(x, y, deltaX, deltaY)
				else if Board.Tiles[x + deltaX][y + deltaY].Element <> E_EMPTY then
					ElementPushablePush(x + deltaX, y + deltaY, deltaX, deltaY);

				if (Board.Tiles[x + deltaX][y + deltaY].Element <> E_EMPTY)
					and ElementDefs[Board.Tiles[x + deltaX][y + deltaY].Element].Destructible
					and (Board.Tiles[x + deltaX][y + deltaY].Element <> E_PLAYER) then
				begin
					BoardDamageTile(x + deltaX, y + deltaY);
				end;

				targetElem := Board.Tiles[x + deltaX][y + deltaY].Element;
				if (targetElem = E_EMPTY) or ((Element = E_PLAYER) and ElementDefs[targetElem].Walkable) then
					ElementMove(x, y, x + deltaX, y + deltaY);
			end;
		end;
	end;

procedure ElementDuplicatorDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do
			case P1 of
				1: ch := 250;
				2: ch := 249;
				3: ch := 248;
				4: ch := 111;
				5: ch := 79;
			else ch := 250 end;
	end;

procedure ElementObjectTick(statId: integer);
	var
		retVal: boolean;
	begin
		with Board.Stats[statId] do begin
			if (DataPos < 0) or (P2 <> 0)
				or not OopExecute(statId, DataPos, 'Interaction')
			then begin
				if (P2 <> 0) and (StepX = 0) and (StepY = 0) then begin
					P2 := P2 - Signum(P2);
				end else if (StepX <> 0) or (StepY <> 0) then begin
					if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then begin
						ElementPushablePush(X + StepX, Y + StepY, StepX, StepY);
					end;

					if ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then begin
						MoveStat(statId, X + StepX, Y + StepY);
						if P2 <> 0 then begin
							P2 := P2 - Signum(P2);
							if P2 = 0 then begin
								StepX := 0;
								StepY := 0;
							end;
						end;
					end else begin
						if P2 = 0 then begin
							retVal := OopSend(-statId, 'THUD', false);
							P2 := 0;
							StepX := 0;
							StepY := 0;
						end else if P2 < 0 then begin
							P2 := 0;
							StepX := 0;
							StepY := 0;							
						end;
					end;
				end;
			end;
		end;
	end;

procedure ElementObjectDraw(x, y: integer; var ch: byte);
	begin
		ch := Board.Stats[GetStatIdAt(x, y)].P1;
	end;

procedure ElementObjectTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		statId: integer;
		retVal: boolean;
	begin
		statId := GetStatIdAt(x, y);
		retVal := OopSend(-statId, 'TOUCH', false);
	end;

procedure ElementDuplicatorTick(statId: integer);
	var
		sourceStatId: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 <= 4 then begin
				P1 := P1 + 1;
				BoardDrawTile(X, Y);
			end else begin
				P1 := 0;
				if Board.Tiles[X - StepX][Y - StepY].Element = E_PLAYER then begin
					ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element]
						.TouchProc(X + StepX, Y + StepY, 0, InputDeltaX, InputDeltaY);
				end else begin
					if Board.Tiles[X - StepX][Y - StepY].Element <> E_EMPTY then
						ElementPushablePush(X - StepX, Y - StepY, -StepX, -StepY);

					if Board.Tiles[X - StepX][Y - StepY].Element = E_EMPTY then begin
						sourceStatId := GetStatIdAt(X + StepX, Y + StepY);
						if sourceStatId > 0 then begin
							if Board.StatCount < (MAX_STAT + 24) then begin
								AddStat(X - StepX, Y - StepY,
									Board.Tiles[X + StepX][Y + StepY].Element,
									Board.Tiles[X + StepX][Y + StepY].Color,
									Board.Stats[sourceStatId].Cycle, Board.Stats[sourceStatId]);
								BoardDrawTile(X - StepX, Y - StepY);
							end;
						end else if sourceStatId <> 0 then begin
							Board.Tiles[X - StepX][Y - StepY]
								:= Board.Tiles[X + StepX][Y + StepY];
							BoardDrawTile(X - StepX, Y - StepY);
						end;

						SoundQueue(3, #48#2#50#2#52#2#53#2#55#2);
					end else begin
						SoundQueue(3, #24#1#22#1);
					end;
				end;

				P1 := 0;
				BoardDrawTile(X, Y);
			end;

			Cycle := (9 - P2) * 3;
		end;
	end;

procedure ElementScrollTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			Board.Tiles[X][Y].Color := Board.Tiles[X][Y].Color + 1;
			if Board.Tiles[X][Y].Color > $0F then
				Board.Tiles[X][Y].Color := $09;

			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementScrollTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		textWindow: TTextWindowState;
		statId: integer;
		unk1: integer;
	begin
		statId := GetStatIdAt(x, y);

		with Board.Stats[statId] do begin
			textWindow.Selectable := false;
			textWindow.LinePos := 1;

			SoundQueue(2, SoundParse('c-c+d-d+e-e+f-f+g-g'));

			DataPos := 0;
			if not OopExecute(statId, DataPos, 'Scroll') then begin
				RemoveStat(GetStatIdAt(x, y));
			end;
		end;
	end;

procedure ElementKeyTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		key: integer;
	begin
		key := Board.Tiles[x][y].Color and 7;

		if World.Info.Keys[key] then begin
			DisplayMessage(200, 'You already have a', ColorNames[key]+' key!');
			SoundQueue(2, #48#2#32#2);
		end else begin
			World.Info.Keys[key] := true;
			BoardRemoveTile(x, y);
			GameUpdateSidebar;
			DisplayMessage(200, 'You now have the', ColorNames[key]+' key.');
			SoundQueue(2, #64#1#68#1#71#1#64#1#68#1#71#1#64#1#68#1#71#1#80#2);
		end;
	end;

procedure ElementAmmoTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		World.Info.Ammo := World.Info.Ammo + 10;

		BoardRemoveTile(x, y);
		GameUpdateSidebar;
		SoundQueue(2, #48#1#49#1#50#1);

		if MessageAmmoNotShown then begin
			MessageAmmoNotShown := false;
			DisplayMessage(200, 'Ammunition:', '10 shots');
		end;
	end;

procedure ElementStoneTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		if World.Info.StonesOfPower < 0 then
			World.Info.StonesOfPower := 0;
		Inc(World.Info.StonesOfPower);

		BoardDamageTile(x, y);
		GameUpdateSidebar;
		DisplayMessage(200, 'You have found a', 'Stone of Power!');
	end;

procedure ElementStoneDraw(x, y: integer; var ch: byte);
	begin
		ch := Random(26) + $41;
	end;

procedure ElementStoneTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			Board.Tiles[X][Y].Color := (Board.Tiles[X][Y].Color and $70) + 9 + Random(7);
			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementGemTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		World.Info.Gems := World.Info.Gems + 1;
		World.Info.Health := World.Info.Health + 10;
		World.Info.Score := World.Info.Score + 10;

		BoardRemoveTile(x, y);
		GameUpdateSidebar;
		SoundQueue(2, #64#1#55#1#52#1#48#1);

		if MessageGemNotShown then begin
			MessageGemNotShown := false;
			DisplayMessage(200, '', 'Gems give you Health!');
		end;
	end;

procedure ElementPassageTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		BoardPassageTeleport(x, y);
		deltaX := 0;
		deltaY := 0;
		if OopSend(0, 'ALL:ENTER', false) then begin end;
	end;

procedure ElementDoorTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		key: integer;
	begin
		key := (Board.Tiles[x][y].Color div 16) and 7;

		if World.Info.Keys[key] then begin
			BoardRemoveTile(x, y);

			World.Info.Keys[key] := false;
			GameUpdateSidebar;

			DisplayMessage(200, 'The '+ColorNames[key]+' door', 'is now open.');
			SoundQueue(3, #48#1#55#1#59#1#48#1#55#1#59#1#64#4);
		end else begin
			DisplayMessage(200, 'The '+ColorNames[key]+' door', 'is locked!');
			SoundQueue(3, #23#1#16#1);
		end;
	end;

procedure ElementPushableTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		ElementPushablePush(x, y, deltaX, deltaY);
		SoundQueue(2, #21#1);
	end;

procedure ElementPusherDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if StepX = 1 then
				ch := 16
			else if StepX = -1 then
				ch := 17
			else if StepY = -1 then
				ch := 30
			else
				ch := 31;
		end;
	end;

procedure ElementPusherTick(statId: integer);
	var
		i, startX, startY: integer;
	begin
		with Board.Stats[statId] do begin
			startX := X;
			startY := Y;

			if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then begin
				ElementPushablePush(X + StepX, Y + StepY, StepX, StepY);
			end;
		end;

		statId := GetStatIdAt(startX, startY);
		with Board.Stats[statId] do begin
			if ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then begin
				MoveStat(statId, X + StepX, Y + StepY);
				SoundQueue(2, #21#1);

				if Board.Tiles[X - (StepX * 2)][Y - (StepY * 2)].Element = E_PUSHER then begin
					i := GetStatIdAt(X - (StepX * 2), Y - (StepY * 2));
					if (Board.Stats[i].StepX = StepX) and (Board.Stats[i].StepY = StepY) then
						ElementDefs[E_PUSHER].TickProc(i);
				end;
			end;
		end;
	end;

procedure ElementInvisibleTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		with Board.Tiles[x][y] do begin
			Element := E_NORMAL;
			BoardDrawTile(x, y);

			SoundQueue(3, #18#1#16#1);
			DisplayMessage(100, 'You are blocked', 'by an invisible wall.');
		end;
	end;

procedure ElementForestTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		Board.Tiles[x][y].Element := E_FLOOR;
		Board.Tiles[x][y].Color := $02;
		BoardDrawTile(x, y);

		ForestSoundTableIdx := (ForestSoundTableIdx + 1) and 7;
		SoundQueue(3, Chr(ForestSoundTable[ForestSoundTableIdx]) + #1);

		if MessageForestNotShown then begin
			DisplayMessage(200, 'A path is cleared', 'through the forest.');
		end;
		MessageForestNotShown := false;
	end;

procedure ElementFakeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		if MessageFakeNotShown then begin
			DisplayMessage(150, 'A fake wall:', 'Secret Passage!');
		end;
		MessageFakeNotShown := false;
	end;

procedure ElementBoardEdgeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		neighborId: integer;
		boardId: integer;
		entryX, entryY: integer;
	begin
		entryX := Board.Stats[0].X;
		entryY := Board.Stats[0].Y;
		if deltaY = -1 then begin
			neighborId := 0;
			entryY := BOARD_HEIGHT;
		end else if deltaY = 1 then begin
			neighborId := 1;
			entryY := 1;
		end else if deltaX = -1 then begin
			neighborId := 2;
			entryX := BOARD_WIDTH;
		end else begin
			neighborId := 3;
			entryX := 1;
		end;

		if Board.Info.NeighborBoards[neighborId] <> 0 then begin
			boardId := World.Info.CurrentBoard;
			BoardChange(Board.Info.NeighborBoards[neighborId]);
			if Board.Tiles[entryX][entryY].Element <> E_PLAYER then begin
				ElementDefs[Board.Tiles[entryX][entryY].Element].TouchProc(
					entryX, entryY, sourceStatId, deltaX, deltaY);
			end;

			if ElementDefs[Board.Tiles[entryX][entryY].Element].Walkable
				or (Board.Tiles[entryX][entryY].Element = E_PLAYER) then
			begin
				if Board.Tiles[entryX][entryY].Element <> E_PLAYER then
					MoveStat(0, -entryX, entryY);

				BoardUpdateDrawOffset;
				TransitionDrawBoardChange;
				ClearDisplayMessage;
				deltaX := 0;
				deltaY := 0;
				BoardEnter;
				if OopSend(0, 'ALL:ENTER', false) then begin end;
			end else begin
				BoardChange(boardId);
			end;
		end;
	end;

procedure ElementLavaTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		SoundQueue(3, #64#1#80#1);
		DisplayMessage(100, 'Your way is', 'blocked by lava.');
	end;

procedure DrawPlayerSurroundings(x, y: integer; bombPhase: integer);
	var
		ix, iy: integer;
		istat: integer;
		result: boolean;
	begin
		for ix := ((x - TORCH_DX) - 1) to ((x + TORCH_DX) + 1) do
			if (ix >= 1) and (ix <= BOARD_WIDTH) then
				for iy := ((y - TORCH_DY) - 1) to ((y + TORCH_DY) + 1) do
					if (iy >= 1) and (iy <= BOARD_HEIGHT) then
						with Board.Tiles[ix][iy] do begin
							if (bombPhase > 0) and ((Sqr(ix-x) + Sqr(iy-y)) < TORCH_DIST_SQR) then begin
								if bombPhase = 1 then begin
									if Length(ElementDefs[Element].ParamTextName) <> 0 then begin
										istat := GetStatIdAt(ix, iy);
										if istat > 0 then
											result := OopSend(-istat, 'BOMBED', false);
									end;

									if ElementDefs[Element].Destructible or (Element = E_STAR) then
										BoardDamageTile(ix, iy);

									if (Element = E_EMPTY) or (Element = E_BREAKABLE) then begin
										Element := E_BREAKABLE;
										Color := $09 + Random(7);
										BoardDrawTile(ix, iy);
									end;
								end else begin
									if Element = E_BREAKABLE then
										Element := E_EMPTY;
								end;
							end;
							BoardDrawTile(ix, iy);
						end;
	end;

procedure GamePromptEndPlay;
	begin
		if World.Info.Health <= 0 then begin
			GamePlayExitRequested := true;
		end else begin
			ClearDisplayMessage;
			GamePlayExitRequested := PromptYesNo('End this game? ', true, $1F);
			if InputKeyPressed = #27 then
				GamePlayExitRequested := false;
		end;
		InputKeyPressed := #0;
	end;

procedure ElementApplyMovement(statId: integer);
	var
		deltaX, deltaY: integer;
	begin
		with Board.Stats[statId] do begin
			if Under.Element in [
				E_WATER_N,
				E_WATER_S,
				E_WATER_W,
				E_WATER_E
			] then begin
				deltaX := 0;
				deltaY := 0;

				case Under.Element of
					E_WATER_N: deltaY := -1;
					E_WATER_S: deltaY := 1;
					E_WATER_W: deltaX := -1;
					E_WATER_E: deltaX := 1;
				end;

				if statId = 0 then begin
					ElementDefs[
						Board.Tiles[X + deltaX][y + deltaY].Element
					].TouchProc(X + deltaX, Y + deltaY, 0, deltaX, deltaY);
				end;

				if ((deltaX <> 0) or (deltaY <> 0)) and ElementDefs[
					Board.Tiles[X + deltaX][y + deltaY].Element
				].Walkable then begin
					MoveStat(statId, X + deltaX, Y + deltaY);
				end;
			end;
		end;
	end;



procedure ElementPlayerTick(statId: integer);
	var
		unk1, unk2, unk3: integer;
		i: integer;
		bulletCount: integer;
		playerColor: integer;
	begin
		with Board.Stats[statId] do begin
			if Under.Element = E_EMPTY then
				playerColor := $0F
			else
				playerColor := (Under.Color and $70) + $0F;

			if World.Info.EnergizerTicks > 0 then begin
				if ElementDefs[E_PLAYER].Character = #2 then
					ElementDefs[E_PLAYER].Character := #1
				else
					ElementDefs[E_PLAYER].Character := #2;

				if (CurrentTick mod 2) <> 0 then
					Board.Tiles[X][Y].Color := $0F
				else
					Board.Tiles[X][Y].Color := (((CurrentTick mod 7) + 1) * 16) + $0F;

				BoardDrawTile(X, Y);
			end else if (ElementDefs[E_PLAYER].Character <> #2) or (Board.Tiles[X][Y].Color <> playerColor) then begin
				Board.Tiles[X][Y].Color := playerColor;
				ElementDefs[E_PLAYER].Character := #2;
				BoardDrawTile(X, Y);
			end;

			if World.Info.Health <= 0 then begin
				InputDeltaX := 0;
				InputDeltaY := 0;
				InputShiftPressed := false;

				if GetStatIdAt(0,0) = -1 then
					DisplayMessage(32000, 'Game over', '-- Press ESCAPE --');

				TickTimeDuration := 0;
				SoundBlockQueueing := true;
			end;

			if InputKeyPressed = ' ' then begin
				InputDeltaX := InputLastDeltaX;
				InputDeltaY := InputLastDeltaY;
				InputShiftPressed := true;
			end;
			if InputShiftPressed then begin
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					if Board.Info.MaxShots = 0 then begin
						if MessageNoShootingNotShown then
							DisplayMessage(200, 'Can'#39't shoot', 'in this place!');
						MessageNoShootingNotShown := false;
					end else if World.Info.Ammo = 0 then begin
						if MessageOutOfAmmoNotShown then
							DisplayMessage(200, 'You don'#39't have', 'any ammo!');
						MessageOutOfAmmoNotShown := false;
					end else begin
						bulletCount := 0;
						for i := 0 to Board.StatCount do
							if (Board.Tiles[Board.Stats[i].X][Board.Stats[i].Y].Element = E_BULLET)
								and (Board.Stats[i].P1 = SHOT_SOURCE_PLAYER)
							then
								bulletCount := bulletCount + 1;

						if bulletCount < Board.Info.MaxShots then begin
							if BoardShoot(E_BULLET, X, Y, InputDeltaX, InputDeltaY, SHOT_SOURCE_PLAYER) then begin
								World.Info.Ammo := World.Info.Ammo - 1;
								GameUpdateSidebar;

								SoundQueue(2, #64#1#48#1#32#1);
							end;
						end;
					end;
				end;

				InputDeltaX := 0;
				InputDeltaY := 0;
			end else if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
				ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].TouchProc(
					X + InputDeltaX, Y + InputDeltaY, 0, InputDeltaX, InputDeltaY);
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					if SoundEnabled and not SoundIsPlaying then
						Sound(110);
					if ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].Walkable then begin
						if SoundEnabled and not SoundIsPlaying then
							NoSound;

						MoveStat(0, X + InputDeltaX, Y + InputDeltaY);
					end else if SoundEnabled and not SoundIsPlaying then begin
						NoSound;
					end;
				end;
			end;

			case UpCase(InputKeyPressed) of
				#27, 'Q': begin
					GamePromptEndPlay;
				end;
				'S': begin
					GameWorldSave('Save game:', SavedGameFileName, '.SAV');
				end;
				'R': begin
					if GameWorldLoad('.SAV', SavedGameFileName) then begin
						ReturnBoardId := World.Info.CurrentBoard;
						BoardChange(ReturnBoardId);
						GamePlayExitRequested := true;
						GamePlayStartRequested := true;						
					end;
				end;
				'P': begin
					if World.Info.Health > 0 then
						GamePaused := true;
				end;
				'B': begin
					SoundEnabled := not SoundEnabled;
					SoundClearQueue;
					GameUpdateSidebar;
					InputKeyPressed := ' ';
				end;
				'H': begin
					if not OopSend(0, 'ALL:HINT', false) then begin
					end;
				end;
				'F': begin
					TextWindowDisplayFile('ORDER.HLP', 'Order form');
				end;
				'?': begin
					GameDebugPrompt;
					InputKeyPressed := #0;
				end;
			end;

			if World.Info.EnergizerTicks > 0 then begin
				World.Info.EnergizerTicks := World.Info.EnergizerTicks - 1;

				if World.Info.EnergizerTicks = 10 then
					SoundQueue(9, #32#3#26#3#23#3#22#3#21#3#19#3#16#3)
				else if World.Info.EnergizerTicks <= 0 then begin
					Board.Tiles[X][Y].Color := playerColor;
					BoardDrawTile(X, Y);
				end;
			end;

			if (Board.Info.TimeLimitSec > 0) and (World.Info.Health > 0) then
				if SoundHasTimeElapsed(World.Info.BoardTimeHsec, 100) then begin
					World.Info.BoardTimeSec := World.Info.BoardTimeSec + 1;

					if (Board.Info.TimeLimitSec - 10) = World.Info.BoardTimeSec then begin
						DisplayMessage(200, '', 'Running out of time!');
						SoundQueue(3, #64#6#69#6#64#6#53#6#64#6#69#6#64#10);
					end else if World.Info.BoardTimeSec > Board.Info.TimeLimitSec then begin
						DamageStat(0);
					end;

					GameUpdateSidebar;
				end;
		end;

		ElementApplyMovement(statId);
	end;

procedure ElementMonitorTick(statId: integer);
	begin
		if UpCase(InputKeyPressed) in [#13, #27] then
			GamePlayExitRequested := true;

		ElementApplyMovement(statId);
	end;

procedure ResetMessageNotShownFlags;
	begin
		MessageAmmoNotShown := true;
		MessageOutOfAmmoNotShown := true;
		MessageNoShootingNotShown := true;
		MessageForestNotShown := true;
		MessageFakeNotShown := true;
		MessageGemNotShown := true;
		MessageEnergizerNotShown := true;
	end;

procedure InitElementDefs;
	var
		i: integer;
	begin
		for i := 0 to MAX_ELEMENT do
			with ElementDefs[i] do begin
				Character := ' ';
				Color := COLOR_CHOICE_ON_BLACK;
				Destructible := false;
				Pushable := false;
				PlaceableOnTop := false;
				Walkable := false;
				HasDrawProc := false;
				Cycle := -1;
				TickProc := ElementDefaultTick;
				DrawProc := ElementDefaultDraw;
				TouchProc := ElementDefaultTouch;
				EditorCategory := 0;
				EditorShortcut := #0;
				Name := '';
				CategoryName := '';
				Param1Name := '';
				Param2Name := '';
				ParamBulletTypeName := '';
				ParamBoardName := '';
				ParamDirName := '';
				ParamTextName := '';
				ScoreValue := 0;
			end;

		ElementDefs[0].Character := ' ';
		ElementDefs[0].Color := $70;
		ElementDefs[0].Pushable := true;
		ElementDefs[0].Walkable := true;
		ElementDefs[0].Name := 'Empty';

		ElementDefs[3].Character := #2;
		ElementDefs[3].Color := $1F;
		ElementDefs[3].Cycle := 1;
		ElementDefs[3].Pushable := true;
		ElementDefs[3].TickProc := ElementMonitorTick;
		ElementDefs[3].Name := 'Monitor';

		ElementDefs[19].Character := 'o';
		ElementDefs[19].Color := $4E;
		ElementDefs[19].PlaceableOnTop := true;
		ElementDefs[19].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[19].TouchProc := ElementLavaTouch;
		ElementDefs[19].EditorShortcut := 'L';
		ElementDefs[19].Name := 'Lava';
		ElementDefs[19].CategoryName := 'Terrains:';

		ElementDefs[20].Character := #176;
		ElementDefs[20].Color := $20;
		ElementDefs[20].Walkable := false;
		ElementDefs[20].TouchProc := ElementForestTouch;
		ElementDefs[20].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[20].EditorShortcut := 'F';
		ElementDefs[20].Name := 'Forest';

		ElementDefs[4].Character := #2;
		ElementDefs[4].Color := $1F;
		ElementDefs[4].Destructible := true;
		ElementDefs[4].Pushable := true;
		ElementDefs[4].Cycle := 1;
		ElementDefs[4].TickProc := ElementPlayerTick;
		ElementDefs[4].EditorCategory := CATEGORY_ITEM;
		ElementDefs[4].EditorShortcut := 'Z';
		ElementDefs[4].Name := 'Player';
		ElementDefs[4].CategoryName := 'Items:';

		ElementDefs[41].Character := #234;
		ElementDefs[41].Color := $0C;
		ElementDefs[41].Destructible := true;
		ElementDefs[41].Pushable := true;
		ElementDefs[41].Cycle := 2;
		ElementDefs[41].TickProc := ElementLionTick;
		ElementDefs[41].TouchProc := ElementDamagingTouch;
		ElementDefs[41].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[41].EditorShortcut := 'L';
		ElementDefs[41].Name := 'Lion';
		ElementDefs[41].CategoryName := 'Beasts:';
		ElementDefs[41].Param1Name := 'Intelligence?';
		ElementDefs[41].ScoreValue := 1;

		ElementDefs[59].Character := #148;
		ElementDefs[59].Color := $0D;
		ElementDefs[59].Destructible := true;
		ElementDefs[59].Pushable := true;
		ElementDefs[59].Cycle := 1;
		ElementDefs[59].TickProc := ElementRotonTick;
		ElementDefs[59].TouchProc := ElementDamagingTouch;
		ElementDefs[59].EditorCategory := CATEGORY_UGLIES;
		ElementDefs[59].EditorShortcut := 'R';
		ElementDefs[59].Name := 'Roton';
		ElementDefs[59].CategoryName := 'Uglies:';
		ElementDefs[59].Param1Name := 'Intelligence?';
		ElementDefs[59].Param2Name := 'Switch Rate?';
		ElementDefs[59].ScoreValue := 2;	

		ElementDefs[60].Character := #237;
		ElementDefs[60].Color := $04;
		ElementDefs[60].Destructible := true;
		ElementDefs[60].Pushable := true;
		ElementDefs[60].Cycle := 2;
		ElementDefs[60].TickProc := ElementDragonPupTick;
		ElementDefs[60].TouchProc := ElementDamagingTouch;
		ElementDefs[60].HasDrawProc := true;
		ElementDefs[60].DrawProc := ElementDragonPupDraw;
		ElementDefs[60].EditorCategory := CATEGORY_UGLIES;
		ElementDefs[60].EditorShortcut := 'D';
		ElementDefs[60].Name := 'Dragon Pup';
		ElementDefs[60].Param1Name := 'Intelligence?';
		ElementDefs[60].Param2Name := 'Switch Rate?';
		ElementDefs[60].ScoreValue := 1;

		ElementDefs[62].Character := #15;
		ElementDefs[62].Color := $FF;
		ElementDefs[62].Destructible := true;
		ElementDefs[62].Pushable := false;
		ElementDefs[62].Cycle := 1;
		ElementDefs[62].TickProc := ElementSpiderTick;
		ElementDefs[62].TouchProc := ElementDamagingTouch;
		ElementDefs[62].EditorCategory := CATEGORY_UGLIES;
		ElementDefs[62].EditorShortcut := 'S';
		ElementDefs[62].Name := 'Spider';
		ElementDefs[62].Param1Name := 'Intelligence?';
		ElementDefs[62].ScoreValue := 3;

		ElementDefs[61].Character := #229;
		ElementDefs[61].Color := $01;
		ElementDefs[61].Destructible := true;
		ElementDefs[61].Pushable := true;
		ElementDefs[61].Cycle := 2;
		ElementDefs[61].TickProc := ElementPairerTick;
		ElementDefs[61].TouchProc := ElementDamagingTouch;
		ElementDefs[61].EditorCategory := CATEGORY_UGLIES;
		ElementDefs[61].EditorShortcut := 'P';
		ElementDefs[61].Name := 'Pairer';
		ElementDefs[61].Param1Name := 'Intelligence?';
		ElementDefs[61].ScoreValue := 2;		

		ElementDefs[42].Character := #227;
		ElementDefs[42].Color := $0B;
		ElementDefs[42].Destructible := true;
		ElementDefs[42].Pushable := true;
		ElementDefs[42].Cycle := 2;
		ElementDefs[42].TickProc := ElementTigerTick;
		ElementDefs[42].TouchProc := ElementDamagingTouch;
		ElementDefs[42].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[42].EditorShortcut := 'T';
		ElementDefs[42].Name := 'Tiger';
		ElementDefs[42].Param1Name := 'Intelligence?';
		ElementDefs[42].Param2Name := 'Firing rate?';
		ElementDefs[42].ParamBulletTypeName := 'Firing type?';
		ElementDefs[42].ScoreValue := 2;

		ElementDefs[44].Character := #233;
		ElementDefs[44].Destructible := true;
		ElementDefs[44].Cycle := 2;
		ElementDefs[44].TickProc := ElementCentipedeHeadTick;
		ElementDefs[44].TouchProc := ElementDamagingTouch;
		ElementDefs[44].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[44].EditorShortcut := 'H';
		ElementDefs[44].Name := 'Head';
		ElementDefs[44].CategoryName := 'Centipedes';
		ElementDefs[44].Param1Name := 'Intelligence?';
		ElementDefs[44].Param2Name := 'Deviance?';
		ElementDefs[44].ScoreValue := 1;

		ElementDefs[45].Character := 'O';
		ElementDefs[45].Destructible := true;
		ElementDefs[45].Cycle := 2;
		ElementDefs[45].TickProc := ElementCentipedeSegmentTick;
		ElementDefs[45].TouchProc := ElementDamagingTouch;
		ElementDefs[45].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[45].EditorShortcut := 'S';
		ElementDefs[45].Name := 'Segment';
		ElementDefs[45].ScoreValue := 3;

		ElementDefs[69].Character := #248;
		ElementDefs[69].Color := $0F;
		ElementDefs[69].Destructible := true;
		ElementDefs[69].Cycle := 1;
		ElementDefs[69].TickProc := ElementBulletTick;
		ElementDefs[69].TouchProc := ElementDamagingTouch;
		ElementDefs[69].Name := 'Bullet';

		ElementDefs[72].Character := 'S';
		ElementDefs[72].Color := $0F;
		ElementDefs[72].Destructible := false;
		ElementDefs[72].Cycle := 1;
		ElementDefs[72].TickProc := ElementStarTick;
		ElementDefs[72].TouchProc := ElementDamagingTouch;
		ElementDefs[72].HasDrawProc := true;
		ElementDefs[72].DrawProc := ElementStarDraw;
		ElementDefs[72].Name := 'Star';

		ElementDefs[8].Character := #12;
		ElementDefs[8].Pushable := true;
		ElementDefs[8].TouchProc := ElementKeyTouch;
		ElementDefs[8].EditorCategory := CATEGORY_ITEM;
		ElementDefs[8].EditorShortcut := 'K';
		ElementDefs[8].Name := 'Key';

		ElementDefs[5].Character := #132;
		ElementDefs[5].Color := $03;
		ElementDefs[5].Pushable := true;
		ElementDefs[5].TouchProc := ElementAmmoTouch;
		ElementDefs[5].EditorCategory := CATEGORY_ITEM;
		ElementDefs[5].EditorShortcut := 'A';
		ElementDefs[5].Name := 'Ammo';

		ElementDefs[64].Character := 'Z';
		ElementDefs[64].Color := $0F;
		ElementDefs[64].Pushable := false;
		ElementDefs[64].TouchProc := ElementStoneTouch;
		ElementDefs[64].Cycle := 1;
		ElementDefs[64].TickProc := ElementStoneTick;
		ElementDefs[64].HasDrawProc := true;
		ElementDefs[64].DrawProc := ElementStoneDraw;
		ElementDefs[64].EditorCategory := CATEGORY_TERRAIN2;
		ElementDefs[64].EditorShortcut := 'Z';
		ElementDefs[64].Name := 'Stone';

		ElementDefs[7].Character := #4;
		ElementDefs[7].Pushable := true;
		ElementDefs[7].TouchProc := ElementGemTouch;
		ElementDefs[7].Destructible := true;
		ElementDefs[7].EditorCategory := CATEGORY_ITEM;
		ElementDefs[7].EditorShortcut := 'G';
		ElementDefs[7].Name := 'Gem';

		ElementDefs[11].Character := #240;
		ElementDefs[11].Color := COLOR_WHITE_ON_CHOICE;
		ElementDefs[11].Cycle := 0;
		ElementDefs[11].TouchProc := ElementPassageTouch;
		ElementDefs[11].EditorCategory := CATEGORY_ITEM;
		ElementDefs[11].EditorShortcut := 'P';
		ElementDefs[11].Name := 'Passage';
		ElementDefs[11].ParamBoardName := 'Room thru passage?';

		ElementDefs[9].Character := #10;
		ElementDefs[9].Color := COLOR_WHITE_ON_CHOICE;
		ElementDefs[9].TouchProc := ElementDoorTouch;
		ElementDefs[9].EditorCategory := CATEGORY_ITEM;
		ElementDefs[9].EditorShortcut := 'D';
		ElementDefs[9].Name := 'Door';

		ElementDefs[10].Character := #232;
		ElementDefs[10].Color := $0F;
		ElementDefs[10].TouchProc := ElementScrollTouch;
		ElementDefs[10].TickProc := ElementScrollTick;
		ElementDefs[10].Pushable := true;
		ElementDefs[10].Cycle := 1;
		ElementDefs[10].EditorCategory := CATEGORY_ITEM;
		ElementDefs[10].EditorShortcut := 'S';
		ElementDefs[10].Name := 'Scroll';
		ElementDefs[10].ParamTextName := 'Edit text of scroll';

		ElementDefs[12].Character := #250;
		ElementDefs[12].Color := $0F;
		ElementDefs[12].Cycle := 2;
		ElementDefs[12].TickProc := ElementDuplicatorTick;
		ElementDefs[12].HasDrawProc := true;
		ElementDefs[12].DrawProc := ElementDuplicatorDraw;
		ElementDefs[12].EditorCategory := CATEGORY_ITEM;
		ElementDefs[12].EditorShortcut := 'U';
		ElementDefs[12].Name := 'Duplicator';
		ElementDefs[12].ParamDirName := 'Source direction?';
		ElementDefs[12].Param2Name := 'Duplication rate?;SF';

		ElementDefs[39].Character := #24;
		ElementDefs[39].Cycle := 2;
		ElementDefs[39].TickProc := ElementSpinningGunTick;
		ElementDefs[39].HasDrawProc := true;
		ElementDefs[39].DrawProc := ElementSpinningGunDraw;
		ElementDefs[39].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[39].EditorShortcut := 'G';
		ElementDefs[39].Name := 'Spinning gun';
		ElementDefs[39].Param1Name := 'Intelligence?';
		ElementDefs[39].Param2Name := 'Firing rate?';
		ElementDefs[39].ParamBulletTypeName := 'Firing type?';

		ElementDefs[35].Character := #5;
		ElementDefs[35].Color := $0D;
		ElementDefs[35].Destructible := true;
		ElementDefs[35].Pushable := true;
		ElementDefs[35].Cycle := 1;
		ElementDefs[35].TickProc := ElementRuffianTick;
		ElementDefs[35].TouchProc := ElementDamagingTouch;
		ElementDefs[35].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[35].EditorShortcut := 'R';
		ElementDefs[35].Name := 'Ruffian';
		ElementDefs[35].Param1Name := 'Intelligence?';
		ElementDefs[35].Param2Name := 'Resting time?';
		ElementDefs[35].ScoreValue := 2;

		ElementDefs[34].Character := #235;
		ElementDefs[34].Color := $02;
		ElementDefs[34].Destructible := true;
		ElementDefs[34].Pushable := true;
		ElementDefs[34].Cycle := 3;
		ElementDefs[34].TickProc := ElementBearTick;
		ElementDefs[34].TouchProc := ElementDamagingTouch;
		ElementDefs[34].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[34].EditorShortcut := 'B';
		ElementDefs[34].Name := 'Bear';
		ElementDefs[34].CategoryName := 'Creatures:';
		ElementDefs[34].Param1Name := 'Sensitivity?';
		ElementDefs[34].ScoreValue := 1;

		ElementDefs[37].Character := '*';
		ElementDefs[37].Color := COLOR_CHOICE_ON_BLACK;
		ElementDefs[37].Destructible := false;
		ElementDefs[37].Cycle := 3;
		ElementDefs[37].TickProc := ElementSlimeTick;
		ElementDefs[37].TouchProc := ElementSlimeTouch;
		ElementDefs[37].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[37].EditorShortcut := 'V';
		ElementDefs[37].Name := 'Slime';
		ElementDefs[37].Param2Name := 'Movement speed?;FS';

		ElementDefs[16].Character := '/';
		ElementDefs[16].Cycle := 3;
		ElementDefs[16].HasDrawProc := true;
		ElementDefs[16].TickProc := ElementConveyorCWTick;
		ElementDefs[16].DrawProc := ElementConveyorCWDraw;
		ElementDefs[16].EditorCategory := CATEGORY_ITEM;
		ElementDefs[16].EditorShortcut := '1';
		ElementDefs[16].Name := 'Clockwise';
		ElementDefs[16].CategoryName := 'Conveyors:';

		ElementDefs[17].Character := '\';
		ElementDefs[17].Cycle := 2;
		ElementDefs[17].HasDrawProc := true;
		ElementDefs[17].DrawProc := ElementConveyorCCWDraw;
		ElementDefs[17].TickProc := ElementConveyorCCWTick;
		ElementDefs[17].EditorCategory := CATEGORY_ITEM;
		ElementDefs[17].EditorShortcut := '2';
		ElementDefs[17].Name := 'Counter';

		ElementDefs[21].Character := #219;
		ElementDefs[21].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[21].CategoryName := 'Walls:';
		ElementDefs[21].EditorShortcut := 'S';
		ElementDefs[21].Name := 'Solid';

		ElementDefs[22].Character := #178;
		ElementDefs[22].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[22].EditorShortcut := 'N';
		ElementDefs[22].Name := 'Normal';

		ElementDefs[31].Character := #206;
		ElementDefs[31].HasDrawProc := true;
		ElementDefs[31].DrawProc := ElementLineDraw;
		ElementDefs[31].Name := 'Line';

		ElementDefs[71].Character := #186;

		ElementDefs[70].Character := #205;

		ElementDefs[32].Character := '*';
		ElementDefs[32].Color := $0A;
		ElementDefs[32].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[32].EditorShortcut := 'R';
		ElementDefs[32].Name := 'Ricochet';

		ElementDefs[23].Character := #177;
		ElementDefs[23].Destructible := false;
		ElementDefs[23].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[23].EditorShortcut := 'B';
		ElementDefs[23].Name := 'Breakable';

		ElementDefs[24].Character := #254;
		ElementDefs[24].Pushable := true;
		ElementDefs[24].TouchProc := ElementPushableTouch;
		ElementDefs[24].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[24].EditorShortcut := 'O';
		ElementDefs[24].Name := 'Boulder';

		ElementDefs[25].Character := #18;
		ElementDefs[25].TouchProc := ElementPushableTouch;
		ElementDefs[25].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[25].EditorShortcut := '1';
		ElementDefs[25].Name := 'Slider (NS)';

		ElementDefs[26].Character := #29;
		ElementDefs[26].TouchProc := ElementPushableTouch;
		ElementDefs[26].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[26].EditorShortcut := '2';
		ElementDefs[26].Name := 'Slider (EW)';

		ElementDefs[30].Character := #197;
		ElementDefs[30].TouchProc := ElementTransporterTouch;
		ElementDefs[30].HasDrawProc := true;
		ElementDefs[30].DrawProc := ElementTransporterDraw;
		ElementDefs[30].Cycle := 2;
		ElementDefs[30].TickProc := ElementTransporterTick;
		ElementDefs[30].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[30].EditorShortcut := 'T';
		ElementDefs[30].Name := 'Transporter';
		ElementDefs[30].ParamDirName := 'Direction?';

		ElementDefs[40].Character := #16;
		ElementDefs[40].Color := COLOR_CHOICE_ON_BLACK;
		ElementDefs[40].HasDrawProc := true;
		ElementDefs[40].DrawProc := ElementPusherDraw;
		ElementDefs[40].Cycle := 4;
		ElementDefs[40].TickProc := ElementPusherTick;
		ElementDefs[40].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[40].EditorShortcut := 'P';
		ElementDefs[40].Name := 'Pusher';
		ElementDefs[40].ParamDirName := 'Push direction?';

		ElementDefs[13].Character := #11;
		ElementDefs[13].HasDrawProc := true;
		ElementDefs[13].DrawProc := ElementBombDraw;
		ElementDefs[13].Pushable := true;
		ElementDefs[13].Cycle := 6;
		ElementDefs[13].TickProc := ElementBombTick;
		ElementDefs[13].TouchProc := ElementBombTouch;
		ElementDefs[13].EditorCategory := CATEGORY_ITEM;
		ElementDefs[13].EditorShortcut := 'B';
		ElementDefs[13].Name := 'Bomb';

		ElementDefs[14].Character := #127;
		ElementDefs[14].Color := $05;
		ElementDefs[14].TouchProc := ElementEnergizerTouch;
		ElementDefs[14].EditorCategory := CATEGORY_ITEM;
		ElementDefs[14].EditorShortcut := 'E';
		ElementDefs[14].Name := 'Energizer';

		ElementDefs[29].Character := #206;
		ElementDefs[29].Cycle := 1;
		ElementDefs[29].TickProc := ElementBlinkWallTick;
		ElementDefs[29].HasDrawProc := true;
		ElementDefs[29].DrawProc := ElementBlinkWallDraw;
		ElementDefs[29].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[29].EditorShortcut := 'X';
		ElementDefs[29].Name := 'Blink wall';
		ElementDefs[29].Param1Name := 'Starting time';
		ElementDefs[29].Param2Name := 'Period';
		ElementDefs[29].ParamDirName := 'Wall direction';

		ElementDefs[27].Character := #178;
		ElementDefs[27].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[27].PlaceableOnTop := true;
		ElementDefs[27].Walkable := true;
		ElementDefs[27].TouchProc := ElementFakeTouch;
		ElementDefs[27].EditorShortcut := 'A';
		ElementDefs[27].Name := 'Fake';

		ElementDefs[47].Character := #176;
		ElementDefs[47].EditorCategory := CATEGORY_TERRAIN2;
		ElementDefs[47].PlaceableOnTop := true;
		ElementDefs[47].Walkable := true;
		ElementDefs[47].EditorShortcut := 'F';
		ElementDefs[47].Name := 'Floor';
		ElementDefs[47].CategoryName := 'Terrains:';

		ElementDefs[63].Character := #197;
		ElementDefs[63].Color := COLOR_CHOICE_ON_BLACK;
		ElementDefs[63].EditorCategory := CATEGORY_TERRAIN2;
		ElementDefs[63].PlaceableOnTop := true;
		ElementDefs[63].Walkable := true;
		ElementDefs[63].EditorShortcut := 'W';
		ElementDefs[63].Name := 'Web';
		ElementDefs[63].HasDrawProc := true;
		ElementDefs[63].DrawProc := ElementWebDraw;
		ElementDefs[63].TouchProc := ElementDefaultTouch;

		ElementDefs[48].Character := #30;
		ElementDefs[48].Color := $19;
		ElementDefs[48].EditorCategory := CATEGORY_TERRAIN2;
		ElementDefs[48].PlaceableOnTop := true;
		ElementDefs[48].Walkable := true;
		ElementDefs[48].EditorShortcut := '8';
		ElementDefs[48].Name := 'Water N';

		ElementDefs[49].Character := #31;
		ElementDefs[49].Color := $19;
		ElementDefs[49].EditorCategory := CATEGORY_TERRAIN2;
		ElementDefs[49].PlaceableOnTop := true;
		ElementDefs[49].Walkable := true;
		ElementDefs[49].EditorShortcut := '2';
		ElementDefs[49].Name := 'Water S';

		ElementDefs[50].Character := #17;
		ElementDefs[50].Color := $19;
		ElementDefs[50].EditorCategory := CATEGORY_TERRAIN2;
		ElementDefs[50].PlaceableOnTop := true;
		ElementDefs[50].Walkable := true;
		ElementDefs[50].EditorShortcut := '4';
		ElementDefs[50].Name := 'Water W';

		ElementDefs[51].Character := #16;
		ElementDefs[51].Color := $19;
		ElementDefs[51].EditorCategory := CATEGORY_TERRAIN2;
		ElementDefs[51].PlaceableOnTop := true;
		ElementDefs[51].Walkable := true;
		ElementDefs[51].EditorShortcut := '6';
		ElementDefs[51].Name := 'Water E';

		ElementDefs[28].Character := ' ';
		ElementDefs[28].EditorCategory := CATEGORY_TERRAIN;
		ElementDefs[28].TouchProc := ElementInvisibleTouch;
		ElementDefs[28].EditorShortcut := 'I';
		ElementDefs[28].Name := 'Invisible';

		ElementDefs[36].Character := #2;
		ElementDefs[36].EditorCategory := CATEGORY_CREATURE;
		ElementDefs[36].Cycle := 3;
		ElementDefs[36].HasDrawProc := true;
		ElementDefs[36].DrawProc := ElementObjectDraw;
		ElementDefs[36].TickProc := ElementObjectTick;
		ElementDefs[36].TouchProc := ElementObjectTouch;
		ElementDefs[36].EditorShortcut := 'O';
		ElementDefs[36].Name := 'Object';
		ElementDefs[36].Param1Name := 'Character?';
		ElementDefs[36].ParamTextName := 'Edit Program';

		ElementDefs[2].TickProc := ElementMessageTimerTick;

		ElementDefs[1].TouchProc := ElementBoardEdgeTouch;

		EditorPatternCount := 5;
		EditorPatterns[1] := E_SOLID;
		EditorPatterns[2] := E_NORMAL;
		EditorPatterns[3] := E_FLOOR;
		EditorPatterns[4] := E_EMPTY;
		EditorPatterns[5] := E_LINE;
	end;

procedure InitElementsEditor;
	begin
		InitElementDefs;
		ElementDefs[28].Character := #176;
		ElementDefs[28].Color := COLOR_CHOICE_ON_BLACK;
		ForceDarknessOff := true;
	end;

procedure InitElementsGame;
	begin
		InitElementDefs;
		ForceDarknessOff := false;
	end;

procedure InitEditorStatSettings;
	var
		i: integer;
	begin
		for i := 0 to MAX_ELEMENT do
			with World.EditorStatSettings[i] do begin
				P1 := 4;
				P2 := 4;
				P3 := 0;
				StepX := 0;
				StepY := -1;
			end;

		World.EditorStatSettings[E_OBJECT].P1 := 1;
		World.EditorStatSettings[E_OBJECT].P2 := 0;
		World.EditorStatSettings[E_BEAR].P1 := 8;
	end;

begin
end.
