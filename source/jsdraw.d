module jsdraw;

version (WebAssembly) {

} else {
	pragma(msg, "jsdraw is only for WebAssembly, use draw.d for a command line draw module");
}

//version (WebAssembly):

import game: GameState, Field, Who, Validity;
extern(C):

void drawRect(double x0, double y0, double w, double h, Color color = cBlack, double alpha = 1);
void drawLine(double x0, double y0, double x1, double y1, double thickness, Color color = cBlack, double alpha = 1);
void drawText(double x, double y, immutable(char)* str, size_t len, Color color = cBlack, double alpha = 1);
void setFont(immutable(char)* str, size_t len);

/// Wrapper to make extracting the ptr and length easier
void drawString(double x, double y, string str, Color color = cBlack, double alpha = 1) {
	drawText(x, y, str.ptr, str.length, color, alpha);
}

/// Wrapper to make extracting the ptr and length easier
void drawSetFont(string font) {
	setFont(font.ptr, font.length);
}

enum canvasWidth = 1024;
enum canvasHeight = 640;
enum fieldX = (canvasWidth-fieldEdge)/2;
enum fieldY = 30;
enum fieldEdge = 500;

alias Color = uint;

enum Color cBlack = 0x000000;
enum Color cGray = 0x888888;
enum Color cWhite = 0xFFFFFF;

enum Color p0color = 0xFF2222;
enum Color p1color = 0x2288FF;
enum Color bckColor = 0x112211;
enum Color fgColor = 0xEEEEFF;
enum Color cursorColor = 0x2288AA;
enum Color previousMoveColor = 0x22DD11;

void drawGameCanvas(in ref GameState state) {
	with (state.Mode) final switch(state.mode) {
		case makeMove: case scramble: case gameOver:
			drawMessage(state);
			drawField(state.field, fieldX, fieldY, fieldEdge);
			drawCursor(state, fieldX, fieldY, fieldEdge);
			break;
		case titleScreen:
			drawSetFont("120px Arial");
			drawString(canvasWidth/2, 250, "Meta tic-tac-toe", fgColor);
			drawSetFont("24px Arial");
			drawString(canvasWidth/2, 400, "August-2018", fgColor);
			drawString(canvasWidth/2, 430, "Click on the screen to start", fgColor);
	}
}

void drawMessage(in ref GameState state) {
	import util: clamp;
	import game: messageStrings;
	drawSetFont("24px Arial");
	auto p = clamp(state.sinceLastMessage, 0, 10) / 10.0;
	drawString(canvasWidth/2, canvasHeight-90+(p*p)*30, messageStrings[state.message], fgColor);
}

void drawCursor(in ref GameState state, double x = fieldX, double y = fieldY, double edge = fieldEdge) {
	if (state.mode != GameState.Mode.makeMove) return;
	drawRect(
		x + state.cursorX*(edge/9.0), 
		y + state.cursorY*(edge/9.0), 
		(edge/9.0),
		(edge/9.0),
		cursorColor, 0.5
		);

	drawString(
		x + state.cursorX.getCellCenter(edge), 
		y + state.cursorY.getCellCenter(edge), 
		state.field.turn.toSymbol, fgColor, 0.5
		);
}

void drawField(in ref Field field, double x, double y, double edge) {

	// Supercells
	foreach(i; 0..3) foreach(j; 0..3) {
		auto player = field.superCellWon[i][j];
		auto margin = edge/60;

		if (player != Who.noone) {
			drawRect(
				x + i*(edge/3) + margin, 
				y + j*(edge/3) + margin, 
				(edge/3) - margin*2, 
				(edge/3) - margin*2,
				player.toColor, 0.5,
				);
		}
	}

	// Outer square
	int outerThickness = 4;
	drawLine(x, y, x+edge, y, outerThickness, fgColor);
	drawLine(x, y+edge, x+edge, y+edge, outerThickness, fgColor);

	drawLine(x, y, x, y+edge, outerThickness, fgColor);
	drawLine(x+edge, y, x+edge, y+edge, outerThickness, fgColor);

	// Inner lines
	for(int i=1; i<9; i++) {
		auto offset = i*edge/9;
		auto innerThickness = ((i%3)==0) ? 2 : 1;
		drawLine(x+offset, y, x+offset, y+edge, innerThickness, fgColor);
		drawLine(x, y+offset, x+edge, y+offset, innerThickness, fgColor);
	}

	// Content
	drawSetFont("30px Arial");
	foreach(i; 0..9) foreach(j; 0..9) {
		auto str = field.fieldContent[i][j].toSymbol;
		drawText(
			x + i.getCellCenter(edge), 
			y + j.getCellCenter(edge), 
			str.ptr, str.length,
			fgColor,
			);

		if (field.validMove[i][j] == Validity.allowed) {
			drawRect(
				x + i*(edge/9.0), y + j *(edge/9.0), 
				(edge/9.0), (edge/9.0),
				fgColor, 0.25);
		}
	}

	if (!field.firstMove) {
		auto margin = edge / 80;
		drawRect(
			x + field.lastMoveX*(edge/9.0)+margin, 
			y + field.lastMoveY*(edge/9.0)+margin, 
			(edge/9.0) - margin*2,
			(edge/9.0) - margin*2,
			previousMoveColor, 0.5
			);
	}
}

// Helper functions
pure private {
	double getCellCenter(int index, double edge) {
		return edge/18+(edge*index/9);
	}
	
	Color alterAlpha(Color c, ubyte alpha) {
		return (c & 0xFFFF_FF00) | alpha;
	}
	
	Color toColor(Who who) {
		final switch (who) {
			case Who.noone: return bckColor;
			case Who.player0: return p0color;
			case Who.player1: return p1color;
		}
	}
	
	string toSymbol(Who who) {
		final switch (who) {
			case Who.noone: return " ";
			case Who.player0: return "X";
			case Who.player1: return "O";
		}
	}
}
