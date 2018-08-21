import game: GameState, Input;


import std.compiler;
//version(all) {
version(WebAssembly) {
extern(C):
	void _start() {} // wasm entry point

	__gshared GameState state;

	void initGame() {
		state.initialize();
	}

	void stepGame(double mouseX, double mouseY, bool click, bool inputRestart, bool inputHint) {
		import jsdraw: fieldX, fieldY, fieldEdge;
		Input input = Input.init;
		if (click) input.enter = true;
		input.selectX = cast(byte) (cast(int) (mouseX - fieldX) / (fieldEdge/9));
		input.selectY = cast(byte) (cast(int) (mouseY - fieldY) / (fieldEdge/9));
		input.hint = inputHint;
		input.restart = inputRestart;
		state.update(input);
	}

	void drawGame() {
		state.draw();
	}

	// These simple C standard library implementations are needed because
	// the compiler inserts calls to these upon struct copying, and if 
	// they aren't provided here it looks for them in the wasm environment...
	// imagine implementing memcpy in javascript.
	// With some luck, LLVM knows how to optimize these for wasm

	void* memcpy(void* destination, const void* source, size_t num)
	{
		int i;
		ubyte* d = cast(ubyte*) destination;
		ubyte* s = cast(ubyte*) source;
		for (i = 0; i < num; i++) {
			d[i] = s[i];
		}
		return destination;
	}

	void* memset(void *source, int value, size_t len) {
		ubyte* dst = cast(ubyte*) source;
		while (len > 0) {
			*dst = cast(ubyte) value;
			dst++;
			len--;
		}
		return source;
	}

	// This one is needed for array boundschecking
	void __assert(const(char)* msg, const(char)* file, uint line) {} 

	// Final note: in debug mode, a 'final switch' statement might want to throw
	// an assert error which is not available in betterC, so it has to be compiled with
	// -release flag passed to ldc!


} else {
	import scone: window;
	enum ticksPerSecond = 30;

	void main()
	{
	    bool loop = true;
	    window.title = "Meta Tic-Tac-Toe";
	    window.resize(69, 26);   //Board is 37*19

		GameState state;

		state.initialize();

	    while(loop)
	    {
			auto input = getInputsFromConsole();
			if (input.exit) loop = false;

			state.update(input);
			state.draw();

			import core.thread: Thread, msecs;
			Thread.sleep((1000/ticksPerSecond).msecs);
	    }
	}

	Input getInputsFromConsole() {
		import scone: SK, SCK;
		Input result;
		foreach(input; window.getInputs())
		{
			if (input.pressed) switch(input.key) 
			{
				case SK.left: result.deltaX = -1; break;
				case SK.right: result.deltaX = +1; break;
				case SK.up: result.deltaY = -1; break;
				case SK.down: result.deltaY = +1; break;
				case SK.space: result.enter = true; break;
				case SK.r: result.restart = true; break;
				case SK.h: result.hint = true; break;
				default: break;
			}
			
			if((input.key == SK.c && input.hasControlKey(SCK.ctrl)) || input.key == SK.escape)
			{
				result.exit = true;
			}
		}
		
		return result;
	}
}
