module boa.values;


import std.algorithm : map;
import std.conv : to;
import std.range : join;

import boa.statements;


final class Value {
	enum Tag { Bool, Int, Function, BuiltinFunction, Array }
	struct FunctionData {
		string[]          parameters;
		Reference[string] closure;
		Statement         body_;
	}
	Tag tag;
	union {
		bool bool_;
		int  int_;
		FunctionData function_;
		Reference delegate(Reference[]) builtinFunction;
		Value[] arrayElements;
	}
	static Value Bool(bool value) { auto v = new Value; v.tag = Tag.Bool; v.bool_ = value; return v; }
	static Value Int(int value) { auto v = new Value; v.tag = Tag.Int; v.int_ = value; return v; }
	static Value Function(string[] parameters, Reference[string] closure, Statement body_) { auto v = new Value; v.tag = Tag.Function; v.function_ = FunctionData(parameters, closure, body_); return v; }
	static Value BuiltinFunction(Reference delegate(Reference[]) value) { auto v = new Value; v.tag = Tag.BuiltinFunction; v.builtinFunction = value; return v; }
	static Value Array(Value[] elements) { auto v = new Value; v.tag = Tag.Array; v.arrayElements = elements; return v; }
	bool isBool() const { return (tag == Tag.Bool); }
	bool isInt() const { return (tag == Tag.Int); }
	bool isFunction() const { return (tag == Tag.Function); }
	bool isBuiltinFunction() const { return (tag == Tag.BuiltinFunction); }
	bool isArray() const { return (tag == Tag.Array); }
	void assign(Value value) {
		tag = value.tag;
		final switch(tag) with(Tag) {
			case Bool:            bool_ = value.bool_; break;
			case Int:             int_ = value.int_; break;
			case Function:        function_ = FunctionData(value.function_.parameters.dup, value.function_.closure, value.function_.body_); break;
			case BuiltinFunction: builtinFunction = value.builtinFunction; break;
			case Array:           arrayElements = value.arrayElements.dup; break;
		}
	}
	override string toString() const {
		final switch(tag) with(Tag) {
			case Bool:            return (bool_ ? "true" : "false");
			case Int:             return int_.to!string;
			case Function:        return "function";
			case BuiltinFunction: return "builtinFunction";
			case Array:           return ("[" ~ arrayElements.map!"a.toString".join(", ") ~ "]");
		}
	}
}


final class Reference {
	enum Tag { LValue, RValue }
	Tag tag;
	union {
		Value lvalue;
		Value rvalue;
	}
	static Reference LValue(Value value) { auto r = new Reference; r.tag = Tag.LValue; r.lvalue = value; return r; }
	static Reference RValue(Value value) { auto r = new Reference; r.tag = Tag.RValue; r.rvalue = value; return r; }
	bool isLValue() const { return (tag == Tag.LValue); }
	bool isRValue() const { return (tag == Tag.RValue); }
	Value value() {
		final switch(tag) with(Tag) {
			case LValue: return lvalue;
			case RValue: return rvalue;
		}
	}
}
