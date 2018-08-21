# Meta-tic-tac-toe
This is a port of a meta tic-tac-toe game written originally in pure x86_64 assembly in October 2015, now written in the D Programming Language. 

The original only compiled on Linux and ran in qemu, but now it can be played either in a Windows / Linux terminal (using [scone](https://github.com/vladdeSV/scone) as backend) or in the browser (by compiling it to [WebAssembly in ldc](https://wiki.dlang.org/Generating_WebAssembly_with_LDC)). 

The port has these main goals:
- Preserve the original game, make it more accessible
- Test the WebAssembly capabilities of D
- Put it in a high level language so it's easier to extend

**Play online:** [Github pages site](https://dkorpel.github.io/tictac/)

**Play in terminal:** [Releases](https://github.com/dkorpel/tictac/releases) or `git clone dub run`

Or compile it:
```
git clone https://github.com/dkorpel/tictac
cd tictac
dub run -release
```

## Compiling
A 64-bit release build can best be done like so:
```
dub run --compiler=ldc2 --arch=x86_64 --build=release
```

This results in a smaller executable and shorter waiting times for the A.I.
It requires the [LDC](https://github.com/ldc-developers/ldc/) compiler to be installed, and on Windows it requires the Microsoft Linker which can be installed from [Visual Studio](https://visualstudio.microsoft.com/) with the 'toolchain Visual C++' component.

There's no WebAssembly target for dub currently, so for wasm, use the included build script:
```
rdmd build wasm
```

It will run this monster of a compiler invocation:
```
ldc2 -mtriple=wasm32-unknown-unknown-wasm -betterC -link-internally -L-allow-undefined -O3 -release -Isource source/app.d source/jsdraw.d source/game.d source/util.d -of="build/wasm"
```

The resulting executable / web page will be in the `build/cmd` or `build/wasm` folder.

## About the Game
The idea of meta tic-tac-toe is explained here: [Ultimate-tic-tac-toe](https://en.wikipedia.org/wiki/Ultimate_tic-tac-toe) 

Differences with the rules listed on Wikipedia:
- The board is randomly pre-filled with 20 pieces to get up to speed in the beginning
- When a player is sent to an already won square, he still has to put his piece there unless it's full
- Additional rule: You can't start in the center square

You play against an A.I. who looks a certain amount of moves ahead.
It evaluates moves by these qualities, in order of importance:
- Winning the game
- Winning a square
- Putting the opponent in a square that's already won

It certainly does not have the best design or implementation, but it has these qualities though:
- It is relatively easy to implement it in Assembly
- It is not so smart that it's impossible for the player to win
- It is a nice benchmark for comparing WebAssembly and native assembly

To elaborate on the last part: There are give or take 6 possible moves every turn, so looking n moves ahead means considering 6^n moves, so the time for the A.I. to take a move grows exponentially with the amount of moves it looks ahead. The assembly version would look about 5 moves ahead in a few seconds, and the compiled version can look about 8 moves ahead in the same time. WebAssembly performance: to be determined.

## About WebAssembly and D:

This was made when WebAssembly was newly added to the ldc compiler.
The [Wasm dither example](https://github.com/allen-garvey/wasm-dither-example) identified a bunch of issues already, so development of this game went very well. One new issue that arose is this:

The compiler may implicitly add function calls to the C standard library to get certain tasks done. For example: initializing an array might be done with `memset`, and copying a struct can be done with `memcpy`. In WebAssembly these symbols aren't available though, so it expects a Javascript implementation in the environment. This results in an error when loading the .wasm file (or it doesn't, if you actually... implemented memcpy and memset in *Javascript*...).

The solution is to add D implementations:
```D
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
```
Doing per byte copies is certainly not the best implementation, so let's hope LLVM's optimizer can make something great out of it.
