module draw;
 
version (WebAssembly) {
	static assert(0, "This draw module is only for a command line environment, use jsdraw for web assembly");
}

extern(C):
import scone: window, Color, fg, bg;
import game: GameState, Field, Who, Validity;


// Color definitions
enum player0Color = Color.blue;
enum player1Color = Color.red;

enum bgField = Color.black_dark.bg;
enum fgField = Color.white_dark.fg;

enum bgSelected = Color.cyan_dark.bg;
enum fgSelected = Color.black_dark.fg;

enum fgPrevious = Color.white.fg;
enum bgPrevious = Color.black.bg;

import util: boxChar;
import std.range: array;
import std.algorithm: map;

enum fieldString = 
"╔═══╤═══╤═══╦═══╤═══╤═══╦═══╤═══╤═══╗
║   │   │   ║   │   │   ║   │   │   ║
╟───┼───┼───╫───┼───┼───╫───┼───┼───╢
║   │   │   ║   │   │   ║   │   │   ║
╟───┼───┼───╫───┼───┼───╫───┼───┼───╢
║   │   │   ║   │   │   ║   │   │   ║
╠═══╪═══╪═══╬═══╪═══╪═══╬═══╪═══╪═══╣
║   │   │   ║   │   │   ║   │   │   ║
╟───┼───┼───╫───┼───┼───╫───┼───┼───╢
║   │   │   ║   │   │   ║   │   │   ║
╟───┼───┼───╫───┼───┼───╫───┼───┼───╢
║   │   │   ║   │   │   ║   │   │   ║
╠═══╪═══╪═══╬═══╪═══╪═══╬═══╪═══╪═══╣
║   │   │   ║   │   │   ║   │   │   ║
╟───┼───┼───╫───┼───┼───╫───┼───┼───╢
║   │   │   ║   │   │   ║   │   │   ║
╟───┼───┼───╫───┼───┼───╫───┼───┼───╢
║   │   │   ║   │   │   ║   │   │   ║
╚═══╧═══╧═══╩═══╧═══╧═══╩═══╧═══╧═══╝".map!boxChar.array;

// Helper functions
pure @nogc @safe {

	/// From a cell x in range [0..9], return the x of where in the terminal window to draw the contents
	int toCellX(int x) {
		return 2+x*4;
	}

	/// From a cell y in range [0..9], return the y of where in the terminal window to draw the contents
	int toCellY(int y) {
		return 1+y*2;
	}

	int toSuperCellX(int x) {
		return 1+x*12;
	}
	int toSuperCellY(int y) {
		return 1+y*6;
	}

	char toSymbol(Who who) {
		final switch (who) {
			case Who.noone: return ' ';
			case Who.player0: return 'X';
			case Who.player1: return 'O';
		}
	}

	Color toColor(Who who) {
		final switch (who) {
			case Who.noone: return Color.black_dark;
			case Who.player0: return player0Color;
			case Who.player1: return player1Color;
		}
	}
}

/**
 * Draw the game in the given state visually in the command line window
 */
void drawGame(ref GameState state) {
	import draw: drawField, drawCursor, drawMessage, drawTitleScreen;
	import scone: window;
	window.clear();
	with (state.Mode) final switch(state.mode) {
		case makeMove: case scramble: case gameOver:
			drawMessage(state);
			drawField(state.field, 16, 3);
			drawCursor(state, 16, 3);
			break;
		case titleScreen:
			drawTitleScreen(state);
	}
	window.print();
}

/**
 * Draw the field of the game containing the board and all naughts and crosses
 */
void drawField(in ref Field field, int x, int y) {
	import util: boxChar;

	window.write(x, y, bgField, fgField, fieldString);

	foreach(i; 0..9) {
		foreach(j; 0..9) {
			window.write(x+i.toCellX, y+j.toCellY, fgField, bgField, field.fieldContent[i][j].toSymbol);
			if (field.validMove[i][j] == Validity.allowed) {
				window.write(x+i.toCellX, y+j.toCellY, fgField, bgField, '░'.boxChar);
			}
		}
	}

	foreach(i; 0..3) {
		foreach(j; 0..3) {
			auto player = field.superCellWon[i][j];
			if (player != Who.noone) {
				foreach(xx; 0..11) {
					foreach(yy; 0..5) {
						window.write(
							x + i.toSuperCellX + xx, 
							y + j.toSuperCellY + yy, 
							player.toColor.bg, Color.white.fg);
					}
				}
			}
		}
	}

	if (!field.firstMove) {
		int xx = x + field.lastMoveX.toCellX;
		int yy = y + field.lastMoveY.toCellY;
		window.write(xx-1, yy, bgPrevious, fgPrevious);
		window.write(xx+0, yy, bgPrevious, fgPrevious);
		window.write(xx+1, yy, bgPrevious, fgPrevious);
	}

}

/**
 * Draw the currently selected cell if there is supposed to be one
 */
void drawCursor(in ref GameState state, int x, int y) {
	if (state.mode == state.Mode.makeMove && state.cursorInRange) {
		int xx = x + state.cursorX.toCellX;
		int yy = y + state.cursorY.toCellY;

		window.write(xx-1, yy, bgSelected, fgSelected);
		window.write(xx+0, yy, bgSelected, fgSelected);
		window.write(xx+1, yy, bgSelected, fgSelected);
	}
}

/**
 * Draw the message text amongside the field giving the player feedback
 */
void drawMessage(in ref GameState state) {
	import game: messageStrings;
	import util: clamp;
	auto str = messageStrings[state.message];
	int i = clamp(state.sinceLastMessage * 4, 0, cast(int) str.length);

	window.write(1, 23, bgField, fgField, str[0..i]);

	import app: benchmarkMoves, benchmarkMsecs, benchmarkShown;
	if (benchmarkShown)
		window.write(1, 24, bgField, fgField, "Evaluated ", benchmarkMoves, " moves in ", benchmarkMsecs, "ms");
}

void drawTitleScreen(in ref GameState) {
	window.write(2, 1, titleText1);
	window.write(2, 20, "August-2018\n\n\nPress space to start");
}

// The presence of \ and ` makes it hard to turn into a nice string literal :(
enum titleText = "
             ___ ___                         
       |\\/| |__   |   /\\                     
       |  | |___  |  /~~\\                    
                                             
___    __     ___       __     ___  __   ___ 
 |  | /  ` __  |   /\\  /  ` __  |  /  \\ |__  
 |  | \\__,     |  /~~\\ \\__,     |  \\__/ |___ 
";

enum titleText1 = `
  ___  ___ _____ _____ ___                                    
  |  \/  ||  ___|_   _/ _ \                                   
  | .  . || |__   | |/ /_\ \                                  
  | |\/| ||  __|  | ||  _  |                                  
  | |  | || |___  | || | | |                                  
  \_|  |_/\____/  \_/\_| |_/                                  

 _____ _____ _____     _____ ___  _____     _____ _____ _____ 
|_   _|_   _/  __ \   |_   _/ _ \/  __ \   |_   _|  _  |  ___|
  | |   | | | /  \/_____| |/ /_\ \ /  \/_____| | | | | | |__  
  | |   | | | |  |______| ||  _  | |  |______| | | | | |  __| 
  | |  _| |_| \__/\     | || | | | \__/\     | | \ \_/ / |___ 
  \_/  \___/ \____/     \_/\_| |_/\____/     \_/  \___/\____/ `;