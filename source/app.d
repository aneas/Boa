import std.conv;
import std.stdio;

final class Value {
	enum Tag { Bool, Int, Function }
	struct FunctionData {
		string[]   parameters;
		Expression body_;
	}
	Tag tag;
	union {
		bool bool_;
		int  int_;
		FunctionData function_;
	}
	static Value Bool(bool value) { auto v = new Value; v.tag = Tag.Bool; v.bool_ = value; return v; }
	static Value Int(int value) { auto v = new Value; v.tag = Tag.Int; v.int_ = value; return v; }
	static Value Function(string[] parameters, Expression body_) { auto v = new Value; v.tag = Tag.Function; v.function_ = FunctionData(parameters, body_); return v; }
	bool isBool() const { return (tag == Tag.Bool); }
	bool isInt() const { return (tag == Tag.Int); }
	bool isFunction() const { return (tag == Tag.Function); }
	override string toString() const {
		final switch(tag) with(Tag) {
			case Bool:     return (bool_ ? "true" : "false");
			case Int:      return int_.to!string;
			case Function: return "function";
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
	Value value() {
		final switch(tag) with(Tag) {
			case LValue: return lvalue;
			case RValue: return rvalue;
		}
	}
}

abstract class Expression {
	abstract Reference evaluate(Environment env);
}

final class IntLiteral : Expression {
	int value;
	this(int value) {
		this.value = value;
	}
	override Reference evaluate(Environment env) {
		return Reference.RValue(Value.Int(value));
	}
}

final class Variable : Expression {
	string name;
	this(string name) {
		this.name = name;
	}
	override Reference evaluate(Environment env) {
		assert(name in env.variables);
		return env.variables[name];
	}
}

final class AddExpression : Expression {
	Expression left, right;
	this(Expression left, Expression right) {
		this.left  = left;
		this.right = right;
	}
	override Reference evaluate(Environment env) {
		auto l = left.evaluate(env).value;
		auto r = right.evaluate(env).value;
		assert(l.isInt);
		assert(r.isInt);
		return Reference.RValue(Value.Int(l.int_ + r.int_));
	}
}

final class FunctionCall : Expression {
	Expression   function_;
	Expression[] arguments;
	this(Expression function_, Expression[] arguments) {
		this.function_ = function_;
		this.arguments = arguments;
	}
	override Reference evaluate(Environment env) {
		auto f = function_.evaluate(env).value;
		Reference[] args;
		foreach(argument; arguments)
			args ~= argument.evaluate(env);
		assert(f.function_.parameters.length == args.length);

		auto localEnv = new Environment;
		foreach(i, parameter; f.function_.parameters)
			localEnv.variables[parameter] = args[i];
		return f.function_.body_.evaluate(localEnv);
	}
}

final class Environment {
	Reference[string] variables;
}

void main() {
	auto expression = new FunctionCall(new Variable("+"), [new IntLiteral(19), new Variable("x")]);
	auto env = new Environment;
	env.variables["x"] = Reference.RValue(Value.Int(23));
	env.variables["+"] = Reference.RValue(Value.Function(["x", "y"], new AddExpression(new Variable("x"), new Variable("y"))));
	auto result = expression.evaluate(env);
	writeln(result.value);
}
