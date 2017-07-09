import std.file : exists, readText;
import std.stdio;

import boa.parser;
import boa.runtime;
import boa.values;


void main(string[] args) {
	if(args.length != 2 || !exists(args[1])) {
		writeln("usage: boa filename");
		return;
	}

	auto filename = args[1];
	auto contents = readText(filename);
	auto program  = parseProgram(contents);

	auto env = new Environment;
	env.variables["+"] = Reference.RValue(Value.BuiltinFunction((Reference[] args) {
		assert(args.length == 2);
		auto l = args[0].value;
		assert(l.isInt);
		auto r = args[1].value;
		assert(r.isInt);
		return Reference.RValue(Value.Int(l.int_ + r.int_));
	}));
	env.variables["*"] = Reference.RValue(Value.BuiltinFunction((Reference[] args) {
		assert(args.length == 2);
		auto l = args[0].value;
		assert(l.isInt);
		auto r = args[1].value;
		assert(r.isInt);
		return Reference.RValue(Value.Int(l.int_ * r.int_));
	}));
	env.variables["writeln"] = Reference.RValue(Value.BuiltinFunction((Reference[] args) {
		foreach(arg; args)
			write(arg.value);
		writeln();
		return Reference.RValue(Value.Int(0));
	}));
	program.execute(env);
}
