module jsdraw;

version (WebAssembly) {

} else {
	static assert(0, "jsdraw is only for WebAssembly, use draw.d for a command line draw module");
}

import app: WindowContext;
import game: GameState, Field, Who, Validity;
extern(C):

void drawGameCanvas(in ref GameState state, in ref WindowContext context) {
	with (context) {
		import util: dclamp;

		with (state.Mode) final switch(state.mode) {
			case makeMove: case scramble: case gameOver:
				drawMessage(state, context);
				drawField(state.field, context, dclamp(state.sinceLastMove/60.0, 0, 1));
				drawCursor(state, context);
				break;
			case titleScreen:
				drawSetFont("120px Arial");
				drawString(context.canvasWidth/2, 250, "Meta tic-tac-toe", fgColor);
				drawSetFont("24px Arial");
				drawString(context.canvasWidth/2, 400, "August-2018", fgColor);
				drawString(context.canvasWidth/2, 430, "Click on the screen to start", fgColor);
		}
	}
}

void drawRect(double x0, double y0, double w, double h, Color color = cBlack);
void drawLine(double x0, double y0, double x1, double y1, double thickness, Color color = cBlack);
void drawText(double x, double y, immutable(char)* str, size_t len, Color color = cBlack);
void drawCircle(double x, double y, double radius, Color color);
void setFont(immutable(char)* str, size_t len);
void setAlpha(double alpha);

/// Wrapper to make extracting the ptr and length easier
void drawString(double x, double y, string str, Color color = cBlack) {
	drawText(x, y, str.ptr, str.length, color);
}

/// Wrapper to make extracting the ptr and length easier
void drawSetFont(string font) {
	setFont(font.ptr, font.length);
}

alias Color = uint;

enum Color cBlack = 0x000000;
enum Color cGray = 0x888888;
enum Color cWhite = 0xFFFFFF;

enum Color p0color = 0xFF2222;
enum Color p1color = 0x2288FF;
enum Color bckColor = 0x112211;
enum Color fgColor = 0xEEEEFF;
enum Color cursorColor = 0x22DD11;
enum Color cursorColorInvalid = 0xEE3322;
enum Color previousMoveColor = 0xAA8844;

void drawMessage(in ref GameState state, WindowContext context) {
	import util: clamp;
	import game: messageStrings;
	drawSetFont("24px Arial");
	auto p = clamp(state.sinceLastMessage, 0, 10) / 10.0;
	drawString(context.canvasWidth/2, context.canvasHeight*0.9 + (p*p)*context.canvasHeight*0.05, 
		messageStrings[state.message], fgColor);
}

void drawCursor(in ref GameState state, in ref WindowContext context) {
	auto edge = context.fieldEdge;
	auto x = context.fieldX;
	auto y = context.fieldY;
	auto validity = state.field.validMove[state.cursorX][state.cursorY];

	if (state.mode != GameState.Mode.makeMove) return;
	setAlpha(0.4);
	drawRect(
		x + state.cursorX*(edge/9.0), 
		y + state.cursorY*(edge/9.0), 
		(edge/9.0),
		(edge/9.0),
		validity == Validity.allowed ? cursorColor : cursorColorInvalid,
		);

	if (validity == Validity.allowed) {
		drawString(
			x + state.cursorX.getCellCenter(edge), 
			y + state.cursorY.getCellCenter(edge), 
			state.field.turn.toSymbol, fgColor
			);
	}
	setAlpha(1.0);
}

void drawField(in ref Field field, in ref WindowContext context, double anim = 1) {
	auto edge = context.fieldEdge;
	auto x = context.fieldX;
	auto y = context.fieldY;
	auto cellEdge = edge / 9;
	auto superCellEdge = edge / 3;

	// Supercells
	foreach(i; 0..3) foreach(j; 0..3) {
		auto player = field.superCellWon[i][j];
		auto margin = edge/60;
		setAlpha(0.5);
		if (player != Who.noone) {
			drawRect(
				x + i*superCellEdge + margin, 
				y + j*superCellEdge + margin, 
				superCellEdge - margin*2, 
				superCellEdge - margin*2,
				player.toColor
				);
		}
		setAlpha(1);
	}

	// Outer square
	int outerThickness = 4;
	drawLine(x, y, x+edge, y, outerThickness, fgColor);
	drawLine(x, y+edge, x+edge, y+edge, outerThickness, fgColor);

	drawLine(x, y, x, y+edge, outerThickness, fgColor);
	drawLine(x+edge, y, x+edge, y+edge, outerThickness, fgColor);

	// Inner lines
	for(int i=1; i<9; i++) {
		auto offset = i * cellEdge;
		auto innerThickness = ((i%3)==0) ? 2 : 1;
		drawLine(x+offset, y, x+offset, y+edge, innerThickness, fgColor);
		drawLine(x, y+offset, x+edge, y+offset, innerThickness, fgColor);
	}

	// Content and valid moves
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
			// "Blink animation", going quickly to alpha 0.75 and slowly back to 0.25
			if (anim > 0.5) setAlpha(1.25-anim);
			else if (anim > 0.25) setAlpha((anim-0.25)*3);
			else setAlpha(0);

			drawRect(
				x + i*cellEdge, y + j *cellEdge, 
				cellEdge, cellEdge,
				fgColor);

			setAlpha(1);
		}
	}

	// Previous move
	if (!field.firstMove) {
		auto margin = edge / 80;
		setAlpha(0.4);

		import util: dclamp;
		auto sizeAnim = dclamp(0.25-anim*4, 0, 1);

		drawCircle(
			x + field.lastMoveX.getCellCenter(edge), 
			y + field.lastMoveY.getCellCenter(edge), 
			cellEdge/2 + sizeAnim*cellEdge,
			previousMoveColor
			);

		setAlpha(1);
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
