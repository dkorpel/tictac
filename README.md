# Meta-tic-tac-toe

![image](https://user-images.githubusercontent.com/14114684/44422238-eae4e100-a582-11e8-94d0-acc3f534b907.png)

**Play online:** [Github pages site](https://dkorpel.github.io/tictac/)

**Play in your terminal:** [Executable Releases](https://github.com/dkorpel/tictac/releases)

Or **compile it yourself**:
```
git clone https://github.com/dkorpel/tictac
cd tictac
dub run
```

---

This is a port of a meta tic-tac-toe game written originally in pure x86_64 assembly in October 2015, now written in the D Programming Language. 

The original only compiled on Linux and ran in qemu, but now it can be played either in a Windows / Linux terminal (using [scone](https://github.com/vladdeSV/scone) as backend) or in the browser (by compiling it to [WebAssembly in ldc](https://wiki.dlang.org/Generating_WebAssembly_with_LDC)). 

The port has these main goals:
- Preserve the original game, make it more accessible
- Test the WebAssembly capabilities of D
- Put it in a high level language so it's easier to extend


## Compiling

While a simple `dub run` works, a 64-bit release build can best be done like so:
```
dub run --compiler=ldc2 --arch=x86_64 --build=release
```

This results in a smaller executable and shorter waiting times for the A.I.
It requires the [LDC](https://github.com/ldc-developers/ldc/) compiler to be installed, and on Windows it requires the Microsoft Linker which can be installed by installing [Visual Studio](https://visualstudio.microsoft.com/) with and adding the 'toolchain Visual C++' component.

There's no WebAssembly target for dub currently, so for wasm, use the included build script:
```
rdmd build wasm
```
The resulting .wasm will be put in the `doc` folder where the webpage also resides.
This webpage can be opened in FireFox locally, but Chrome doesn't allow the http request to a local file so the game won't load. You can use something like [live-server](https://www.npmjs.com/package/live-server) to still test it without deploying. 

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

To elaborate on the last part: There are give or take 6 possible moves every turn, so looking n moves ahead means considering 6^n moves, so the time for the A.I. to take a move grows exponentially with the amount of moves it looks ahead. The assembly version would look about 5 moves ahead in a few seconds, and the compiled version can look about 8 moves ahead in the same time.

## Performance

The only performance critical part of this game is the A.I., so we can use this to see how fast different versions run. 
I did a quick test comparing the command line version compiled with DMD and LDC using dub's debug and release configurations, and the WebAssembly version (which is compiled with LDC with -O3). The A.I. is asked to look 8 moves deep, and in total 1975681 moves were evaluated. Results:

| Version       | Time    | Factor |
|---------------|---------|--------|
| Ldc (release) |  357 ms | 1.0    |
| Dmd (release) |  671 ms | 1.9    |
| Wasm          |  967 ms | 2.7    |
| Dmd (debug)   | 1651 ms | 4.6    |
| Ldc (debug)   | 2159 ms | 6.0    |

This is by no means a thorough performance analysis, but it gives some idea of what kind of performance to expect from WebAssembly.

## About WebAssembly and D

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
