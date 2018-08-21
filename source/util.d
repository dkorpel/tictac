module util;

extern(C):
@nogc:

// Random seed variables
struct RandomSeed {
	ubyte x = 148;
	ubyte a = 0;
	ubyte b = 0;
	ubyte c = 0;
}
__gshared RandomSeed randomSeed;

ubyte getRandom8() {
	with(randomSeed) {
		a = a^c^x;
		const tmpb = b + a;
		c += (tmpb>>1)^a;
		b = cast(ubyte) tmpb;
		return c;
	}
}

ushort get_random16() {
	return (getRandom8() << 8) | getRandom8();
}

int getRandom(ushort n) {
	return get_random16() % n;
}

int clamp(int val, int min, int max) {
	return (val < min ? min : (val > max ? max : val));
}

double dclamp(double val, double min, double max) {
	return (val < min ? min : (val > max ? max : val));
}

double dmax(double a, double b) {
	return a > b ? a : b;
}

double dmin(double a, double b) {
	return a < b ? a : b;
}

/**
Maps Unicode to Extended Ascii so it can be printed in the Terminal
 */
char boxChar(dchar input) {
	switch (input) {
		case '\n': return '\n';
		case 32: .. case 127: return cast(char) input;
		case '░': return 176;
		case '▒': return 177;
		case '▓': return 178;
		case '│': return 179;
		case '┤': return 180;
		case '╡': return 181;
		case '╢': return 182;
		case '╖': return 183;
		case '╕': return 184;
		case '╣': return 185;
		case '║': return 186;
		case '╗': return 187;
		case '╝': return 188;
		case '╜': return 189;
		case '╛': return 190;
		case '┐': return 191;
		case '└': return 192;
		case '┴': return 193;
		case '┬': return 194;
		case '├': return 195;
		case '─': return 196;
		case '┼': return 197;
		case '╞': return 198;
		case '╟': return 199;
		case '╚': return 200;
		case '╔': return 201;
		case '╩': return 202;
		case '╦': return 203;
		case '╠': return 204;
		case '═': return 205;
		case '╬': return 206;
		case '╧': return 207;
		case '╨': return 208;
		case '╤': return 209;
		case '╥': return 210;
		case '╙': return 211;
		case '╘': return 212;
		case '╒': return 213;
		case '╓': return 214;
		case '╫': return 215;
		case '╪': return 216;
		case '┘': return 217;
		case '┌': return 218;
		case '█': return 219;
		case '▄': return 220;
		case '▌': return 221;
		case '▐': return 222;
		case '▀': return 223;
		case '■': return 254;
		default: return '?';
	}
}
