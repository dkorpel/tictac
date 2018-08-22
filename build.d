#!/usr/bin/env rdmd
module build;

/*
Simple script for building the game. Why not use:
  dub: no WebAssembly, need to specify preferred architecture / compiler in flags
  .bat / .sh scripts: I hate the syntax
  make: not pre-installed on Windows
  any of the other gazillion build systems: not pre-installed
*/

import std.process: ProcessException, execute;
import std.file: exists, mkdirRecurse;
import std.path: buildPath;
import std.stdio: writeln;

int main(string[] args) {
	if (args.length == 2) {
		switch (args[1]) {
			case "wasm": return buildWasm();
			case "cmd32": return buildCmd("x86");
			case "cmd64": return buildCmd("x86_64");
			default: break;
		}
	}
	writeln("Usage: rdmd build [option]");
	writeln("Options are:");
	writeln("  cmd32   command line executible (32-bit)");
	writeln("  cmd64   command line executible (64-bit)");
	writeln("  wasm    Webpage with Web Assembly");
	return -1;
}

int buildCmd(string arch = "x86_64") {

	auto path = buildPath("build");
	if (exists(path)) {
		mkdirRecurse(path);
	}

	auto result = execute(["dub", "build", "--compiler=ldc2", "--arch="~arch, "--build=release"]);
	if (!result[0]) {
		writeln("Build succesful");
		writeln(result[1]);
		writeln("Look in the folder '", path, "'");
	} else {
		writeln("Build failed:");
		writeln(result[1]);
	}
	return 0;
}

int buildWasm() {

	auto dest = "docs";
	if (exists(dest)) {
		mkdirRecurse(dest);
	}

	enum wasmOptions = [
		"-mtriple=wasm32-unknown-unknown-wasm", 
		"-betterC", 
		"-link-internally", 
		"-L-allow-undefined",
	];
	enum releaseOptions = ["-O3", "-release"];
	enum files = ["-Isource", 
		"source/app.d", 
		"source/jsdraw.d", 
		"source/game.d", 
		"source/util.d"
	];

	try {
		auto result = execute(
			["ldc2", "-of="~dest~"/tictac.wasm"] ~ wasmOptions ~ releaseOptions ~ files
		);
		if (result[0]) {
			writeln("Build failed:");
			writeln(result[1]);
		}

	} catch (ProcessException e) {
		writeln("Ldc was not found. You can download it here: https://github.com/ldc-developers/ldc/releases");
		writeln("And make sure it's added to the PATH environment variable");
		return -1;
	}
	return 0;
}
