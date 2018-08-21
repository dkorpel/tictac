module game;

extern(C):
@nogc: //note: this nogc doesn't apply to member functions

/**
 * General type for referring to either player or neither.
 */
enum Who: byte 
{
	noone,
	player0,
	player1,
}

/// Currently hard-coded, but possible to have 2-player modes
bool isCpu(Who who, in ref GameState) {
	final switch(who) {
		case Who.noone: return false;
		case Who.player0: return false;
		case Who.player1: return true;
	}
}

/**
 * Whether a move is allowed and if not, which rule prevents it from being allowed
 */
enum Validity: byte {
	allowed,
	disallowed,
	occupied,
	wrongSuperCell,
	sendingBack,
	centerFirstMove,
}

/**
 * A subset of the game state related to the field,
 * which is basically everything modulo user interface stuff
 */
struct Field 
{
	// Workaround for a bug where static initializers don't work on static 2D arrays in structs
	Who[9][9] fieldContent = (){Who[9][9] who; foreach(i; 0..9*9) {who[i%9][i/9] = Who.noone;} return who;}();
	Who[3][3] superCellWon = (){Who[3][3] who; foreach(i; 0..3*3) {who[i%3][i/3] = Who.noone;} return who;}();
	Validity[9][9] validMove = (){Validity[9][9] b; foreach(i; 0..9*9) {b[i%9][i/9] = Validity.disallowed;} return b;}();
	byte player0supercells = 0;
	byte player1supercells = 0;
	byte lastMoveX = -1;
	byte lastMoveY = -1;
	bool firstMove = true;
	bool newSuperCellWon = false;
	byte validMoves = 0;
	Who gameWon = Who.noone;
	Who turn = Who.player0;
}

/**
 * The object containing all of the game's state. 
 */
struct GameState 
{
	Field field;
	enum Mode: byte 
	{
		titleScreen,
		scramble,
		makeMove,
		gameOver,
	}

	Mode mode = Mode.titleScreen;
	byte cursorX = 4;
	byte cursorY = 4;
	bool cursorInRange = true;
	byte cpuRecursionLevel = 8; /// How many moves the cpu looks ahead
	int sinceLastMessage = 0;
	int sinceLastMove;
	int globalTimer = 0;

	InfoMessage message = InfoMessage.none;

	/// Reset the game state
	void initialize() @nogc {
		this = GameState.init;
	}

	/// Update the game state
	void update(Input input) @nogc {
		// Forward it to a free function to keep the struct concise
		updateGame(this, input);
	}

	/// Draw this game 
	void draw() {
		version(WebAssembly) {
			import jsdraw: drawGameCanvas;
			import app: windowContext;
			drawGameCanvas(this, windowContext); // different because name conflict in exported function
		} else {
			// Notably NOT nogc if commandline
			import draw: drawGame;
			drawGame(this);
		}
	}
}

/**
 * All user input that can alter the game state
 */
struct Input 
{
	byte deltaX = 0;
	byte deltaY = 0;
	bool enter = false;
	bool restart = false;
	bool exit = false;
	bool hint = false;
	bool selectInRange = true;
	byte selectX = -1;
	byte selectY = -1;
}

///////////////////////////////////////////////////////////////
/**
 * All possible messages that can appear alongside the view giving the player
 * feedback on what is happening.
 */
enum InfoMessage: byte {
	none,
	startGameInstruction,
	firstMove,
	noStartingAtCenter,
	noSendingBack,
	chooseEmptyCell,
	putInCorrectSuperCell,
	yourTurn,
	playerWon,
	cpuWon,
	tie,
	player0turn,
	player1turn,
}

/**
 * Corresponding message strings for infomessages. IMPORTANT: keep them in sync!
 * I'm not using the X macro.
 */
version (WebAssembly) {
	__gshared immutable string[] messageStrings = [
		"",
		"Click to create a new board  ",
		"Make your first move. Click on an empty highlighted spot to make a move there.",
		"First move can't be in the center square",
		"Can't send the other player back to the previous square",
		"Choose an empty cell",
		"Put it in the square corresponding to the cell of the previous move",
		"Your turn",
		"Congratulations, you won!",
		"Better luck next time!",
		"No valid moves left - we'll consider it a tie.",
		"Player 1's turn to place an x",
		"Player 2's turn to place an o",
	];
} else {
	__gshared immutable string[] messageStrings = [
		"",
		"Press space to create a new board  ",
		"Make your first move. Move the cursor with the arrow keys and use\nspace to make a move.",
		"First move can't be in the center square",
		"Can't send the other player back to the previous square",
		"Choose an empty cell",
		"Put it in the square corresponding to the cell of the previous move",
		"Your turn",
		"Congratulations, you won! Press R to reset",
		"Better luck next time! Press R to reset",
		"No valid moves left - we'll consider it a tie. Press R to reset",
		"Player 1's turn to place an x",
		"Player 2's turn to place an o",
	];
}

///////////////////////////////////////////////////////////////
private:

/**
 * The game update function that should be called many times per second
 */
void updateGame(ref GameState state, Input input) {

	if (input.restart) {
		state.initialize();
	}

	with(state) final switch (mode) 
	{
		case Mode.titleScreen:
			if (input.enter)
			{
				mode = Mode.scramble;
				state.setMessage(InfoMessage.startGameInstruction);
			}
			break;
		case Mode.scramble:
			if ((globalTimer % 4) == 0) state.field.randomizeField();
			if (input.enter)
			{
				field.getValidMoves();
				mode = Mode.makeMove;
				state.sinceLastMove = 0;
				state.setMessage(InfoMessage.firstMove);
			}
			break;
		case Mode.makeMove:

			if (!field.turn.isCpu(state)) {
				import util: clamp;
				cursorInRange = input.selectInRange;
				cursorX = cast(byte) clamp(cursorX + input.deltaX, 0, 8);
				cursorY = cast(byte) clamp(cursorY + input.deltaY, 0, 8);

				if (input.selectX >= 0 && input.selectX < 9 && input.selectY >= 0 && input.selectY < 9) {
					cursorX = input.selectX;
					cursorY = input.selectY;
				}

				if (input.enter && cursorInRange) {
					playerTryMove(state, cursorX, cursorY);
				} else if (input.hint) {
					cpuDoMove(state);
				}
			} else {
				if (state.sinceLastMove >= 90 || input.enter) {
					cpuDoMove(state);
				}
			}

			if (field.gameWon != Who.noone) {
				mode = Mode.gameOver;
				state.setMessage(field.gameWon == Who.player0 ? InfoMessage.playerWon : InfoMessage.cpuWon);
			} else if (field.validMoves == 0){
				mode = Mode.gameOver;
				state.setMessage(InfoMessage.tie);
			}

			break;
		case Mode.gameOver:

			break;
	}

	state.sinceLastMove++;
	state.sinceLastMessage++;
	state.globalTimer++;
}

/**
 * Display a message. Overwrites the previous message
 */
void setMessage(ref GameState state, InfoMessage message) {
	state.message = message;
	state.sinceLastMessage = 0;
}

/**
 * Fill the field randomly and fairly to get up to speed instead of 
 * doing 20 moves on an almost empty field.
 */
void randomizeField(ref Field field) {
	import util: getRandom;

	for (int i=0; i<9; i++) {
		for (int j=0; j<9; j++) {
			field.fieldContent[i][j] = Who.noone;
		}
	}

	for (int i=0; i<9; i+=3) {
		for (int j=0; j<9; j+=3) {
			foreach(c; 0..1000) {
				int x = i+getRandom(3);
				int y = j+getRandom(3);

				if (x == 4 && y == 4) continue; //middle square is always free

				if (field.fieldContent[x][y] == Who.noone) {
					field.fieldContent[x][y] = Who.player0;
					field.fieldContent[8-x][8-y] = Who.player1;
					break;
				}
			}
		}
	}
}

/**
 * Let the player make a move at cell x, y if it is allowed,
 * else give feedback why it's an invalid move
 */
void playerTryMove(ref GameState state, int x, int y) {

	auto val = state.field.validMove[x][y];
	if (val == Validity.allowed) {
		state.field.doMove(x, y);
		state.updateAfterMove();
	} else {
		final switch (val) {
			case Validity.allowed: case Validity.disallowed:
				// Shouldn't be possible
				break;
			case Validity.centerFirstMove:
				state.setMessage(InfoMessage.noStartingAtCenter);
				break;
			case Validity.sendingBack:
				state.setMessage(InfoMessage.noSendingBack);
				break;
			case Validity.wrongSuperCell:
				state.setMessage(InfoMessage.putInCorrectSuperCell);
				break;
			case Validity.occupied:
				state.setMessage(InfoMessage.chooseEmptyCell);
				break;
		}
	}
}

void updateAfterMove(ref GameState state) {
	// Move cursor to the right square
	version (WebAssembly) {

	} else {
		state.cursorX = 1 + (state.field.lastMoveX % 3) * 3;
		state.cursorY = 1 + (state.field.lastMoveY % 3) * 3;
	}
	state.setMessage(state.field.turn == Who.player0 ? InfoMessage.player0turn : InfoMessage.player1turn);
	state.sinceLastMove = 0;
}

/*
 * Do a move on the field on the cell at position x, y
 * It doesn't check whether the move is allowed
 */
void doMove(ref Field field, int x, int y) {
	field.fieldContent[x][y] = field.turn;
	field.turn = field.turn == Who.player0 ? Who.player1 : Who.player0;
	field.firstMove = false;
	field.lastMoveX = cast(byte) x;
	field.lastMoveY = cast(byte) y;

	Who w = field.checkSupercellWin(x/3, y/3);
	if (field.superCellWon[x/3][y/3] == Who.noone && w != Who.noone) {
		field.superCellWon[x/3][y/3] = w;
		field.newSuperCellWon = true;
	} else {
		field.newSuperCellWon = false;
	}

	Who winner = field.checkGameWin();
	if (winner != Who.noone) {
		field.gameWon = winner;
		field.validMoves = 0;
	} else {
		field.getValidMoves();
	}

}

// Cap amount of moves to prevent absurd waiting times for A.I.
__gshared int totalMovesConsidered = 0;
enum maxMovesConsidered = 3_000_000;

/**
 * Ask the cpu to do a move, either as an opponent or to provide a hint to the player
 */
void cpuDoMove(ref GameState state) {
	int x, y;
	totalMovesConsidered = 0;

	import app: benchmarkStart, benchmarkEnd;

	benchmarkStart();
	bestMoveScore(state.field, state.cpuRecursionLevel, x, y);
	benchmarkEnd(totalMovesConsidered);
	
	state.field.doMove(x, y);
	state.updateAfterMove();
}

/**
 * Try to find the score of the best move possible 
 */
int bestMoveScore(ref Field field, int recursions, out int x, out int y) {
	int bestScore = int.min;
	x = 0;
	y = 0;

	if (recursions <= 0 || field.gameWon != Who.noone || 
		field.validMoves == 0 || totalMovesConsidered >= maxMovesConsidered) {
		return 0;
	}

	foreach(i; 0..9) foreach(j; 0..9) {
		if (field.validMove[i][j] == Validity.allowed) {
			totalMovesConsidered++;
			Field tempField = field;
			tempField.doMove(i, j);
			version (none) debug {
				// Visualize the 'thinking process'
				import draw:drawField;
				import scone: window;
				import core.thread: Thread, msecs;
				drawField(tempField, 0, 0);
				window.write(0, 0, recursions);
				window.print();
				Thread.sleep(100.msecs);
			}

			int sink = void;
			int score = moveEvaluateScore(tempField) - bestMoveScore(tempField, recursions-1, sink, sink);
			if (score > bestScore) {
				x = i;
				y = j;
				bestScore = score;
			}
		}
	}

	return bestScore;
}

/**
 * Find how 'good' a move is using some simple cases:
 * Winning the game
 * Winning a supercell
 * Making the player go to a useless supercell
 * 
 * If none applies, just give a random score
 */
int moveEvaluateScore(in ref Field field) {
	import util: getRandom;

	if (field.gameWon != Who.noone) {
		return 60;
	} else if (field.newSuperCellWon) {
		return 20;
	} else if (!field.firstMove && field.superCellWon[field.lastMoveX/3][field.lastMoveY/3] != Who.noone) {
		return 10;
	} else {
		return getRandom(3)+1;
	}
}

/**
 * Find which moves are currently allowed according to the rules
 */
void getValidMoves(ref Field field) {

	foreach(i; 0..9) foreach(j; 0..9) {
		field.validMove[i][j] = Validity.wrongSuperCell;
	}

	field.validMoves = 0;

	if (!field.firstMove) {
		int x0 = (field.lastMoveX % 3) * 3;
		int y0 = (field.lastMoveY % 3) * 3;


		foreach(i; 0..3) foreach(j; 0..3) {
			// Can't override existing move
			if (field.fieldContent[x0+i][y0+j] != Who.noone) {
				field.validMove[x0+i][y0+j] =  Validity.occupied;
			} else if (i == (field.lastMoveX / 3) && j == (field.lastMoveY / 3)) {
				field.validMove[x0+i][y0+j] =  Validity.sendingBack;
			} else if (field.fieldContent[x0+i][y0+j] == Who.noone) {
				field.validMove[x0+i][y0+j] =  Validity.allowed;
				field.validMoves++;
			}
		}

		// If no moves are possible, any empty square on the board is allowed
		if (field.validMoves == 0) {
			foreach(i; 0..9) foreach(j; 0..9) {
				if (field.fieldContent[i][j] != Who.noone) {
					field.validMove[i][j] = Validity.occupied;
				} else {
					field.validMove[i][j] = Validity.allowed;
					field.validMoves++;
				}
			}
		}
	} else {
		// First move: anywhere open, except center square
		foreach(i; 0..9) foreach(j; 0..9) {
			if (i >= 3 && i < 6 && j >= 3 && j < 6) {
				field.validMove[i][j] = Validity.centerFirstMove;
			} else if (field.fieldContent[i][j] != Who.noone) {
				field.validMove[i][j] = Validity.occupied;
			} else {
				field.validMove[i][j] = Validity.allowed;
				field.validMoves++;
			}
			
		}
	}
}

/**
 * Looks for three in a row in a supercell. x and y are the supercell index,
 * and they must be in the [0, 3[ range.
 */
Who checkSupercellWin(in ref Field field, int x, int y) pure {
	return checkThreeInARow(field.fieldContent, x*3, y*3);
}

/**
 * Looks for three won supercells in a row, which determines the game's winner.
 */
Who checkGameWin(in ref Field field) pure {
	return checkThreeInARow(field.superCellWon, 0, 0);
}

/**
 * Check whether there are three in a row in a 2d array at
 * offset (x, y). 
 * Template function so it can be used with static arrays
 * for both the 3x3 supercell array and the 9x9 cell array
 */
Who checkThreeInARow(T)(in ref T f, int x, int y) {
	foreach(i; 0..3) {
		// Horizontal row
		if (f[x+0][y+i] != Who.noone) {
			if (f[x+0][y+i] == f[x+1][y+i] && f[x+1][y+i] == f[x+2][y+i]) {
				return f[x+2][y+i];
			}
		}
		
		// Vertical row
		if (f[x+i][y+0] != Who.noone) {
			if (f[x+i][y+0] == f[x+i][y+1] && f[x+i][y+1] == f[x+i][y+2]) {
				return f[x+i][y+2];
			}
		}
	}
	
	// Diagonal row \ 
	if (f[x][y] != Who.noone) {
		if (f[x][y] == f[x+1][y+1] && f[x+1][y+1] == f[x+2][y+2]) {
			return f[x][y];
		}
	}
	
	// Diagonal row / 
	if (f[x+2][y] != Who.noone) {
		if (f[x+2][y] == f[x+1][y+1] && f[x+1][y+1] == f[x+0][y+2]) {
			return f[x+2][y];
		}
	}
	
	return Who.noone;
}
