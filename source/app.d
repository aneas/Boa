import std.conv;
import std.stdio;

final class Value {
	enum Tag { Bool, Int, Function, BuiltinFunction }
	struct FunctionData {
		string[]   parameters;
		Expression body_;
	}
	Tag tag;
	union {
		bool bool_;
		int  int_;
		FunctionData function_;
		Reference delegate(Reference[]) builtinFunction;
	}
	static Value Bool(bool value) { auto v = new Value; v.tag = Tag.Bool; v.bool_ = value; return v; }
	static Value Int(int value) { auto v = new Value; v.tag = Tag.Int; v.int_ = value; return v; }
	static Value Function(string[] parameters, Expression body_) { auto v = new Value; v.tag = Tag.Function; v.function_ = FunctionData(parameters, body_); return v; }
	static Value BuiltinFunction(Reference delegate(Reference[]) value) { auto v = new Value; v.tag = Tag.BuiltinFunction; v.builtinFunction = value; return v; }
	bool isBool() const { return (tag == Tag.Bool); }
	bool isInt() const { return (tag == Tag.Int); }
	bool isFunction() const { return (tag == Tag.Function); }
	bool isBuiltinFunction() const { return (tag == Tag.BuiltinFunction); }
	void assign(Value value) {
		tag = value.tag;
		final switch(tag) with(Tag) {
			case Bool:            bool_ = value.bool_; break;
			case Int:             int_ = value.int_; break;
			case Function:        function_ = FunctionData(value.function_.parameters.dup, value.function_.body_); break;
			case BuiltinFunction: builtinFunction = value.builtinFunction; break;
		}
	}
	override string toString() const {
		final switch(tag) with(Tag) {
			case Bool:            return (bool_ ? "true" : "false");
			case Int:             return int_.to!string;
			case Function:        return "function";
			case BuiltinFunction: return "builtinFunction";
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

struct Action {
	enum Tag { Proceed, Return }
	Tag tag;
	union {
		Reference returnValue;
	}
	static Action Proceed() { return Action(Tag.Proceed); }
	static Action Return(Reference value) { Action a; a.tag = Tag.Return; a.returnValue = value; return a; }
	bool isProceed() const { return (tag == Tag.Proceed); }
	bool isReturn() const { return (tag == Tag.Return); }
}

final class Program {
	Statement[] statements;
	this(Statement[] statements) {
		this.statements = statements;
	}
	Action execute(Environment env) {
		foreach(statement; statements) {
			auto action = statement.execute(env);
			if(action.isReturn)
				return action;
		}
		return Action.Proceed;
	}
}

abstract class Statement {
	abstract Action execute(Environment env);
}

final class ExpressionStatement : Statement {
	Expression expression;
	this(Expression expression) {
		this.expression = expression;
	}
	override Action execute(Environment env) {
		expression.evaluate(env);
		return Action.Proceed;
	}
}

final class ReturnStatement : Statement {
	Expression expression;
	this(Expression expression) {
		this.expression = expression;
	}
	override Action execute(Environment env) {
		auto result = expression.evaluate(env);
		return Action.Return(result);
	}
}

final class Assignment : Statement {
	Expression left, right;
	this(Expression left, Expression right) {
		this.left  = left;
		this.right = right;
	}
	override Action execute(Environment env) {
		auto l = left.evaluate(env);
		assert(l.isLValue);
		auto r = right.evaluate(env).value;
		l.lvalue.assign(r);
		return Action.Proceed;
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

		if(f.isFunction) {
			assert(f.function_.parameters.length == args.length);
			auto localEnv = new Environment;
			foreach(i, parameter; f.function_.parameters)
				localEnv.variables[parameter] = args[i];
			return f.function_.body_.evaluate(localEnv);
		}
		else if(f.isBuiltinFunction)
			return f.builtinFunction(args);
		else
			assert(false);
	}
}

final class Environment {
	Reference[string] variables;
}

void main() {
	auto program = new Program([
		new Assignment(new Variable("x"), new IntLiteral(23)),
		new ReturnStatement(new FunctionCall(new Variable("+"), [new IntLiteral(19), new Variable("x")]))
	]);
	auto env = new Environment;
	env.variables["x"] = Reference.LValue(Value.Int(3));
	env.variables["+"] = Reference.RValue(Value.BuiltinFunction((Reference[] args) {
		assert(args.length == 2);
		auto l = args[0].value;
		assert(l.isInt);
		auto r = args[1].value;
		assert(r.isInt);
		return Reference.RValue(Value.Int(l.int_ + r.int_));
	}));
	auto action = program.execute(env);
	if(action.isReturn)
		writeln("result: ", action.returnValue.value);
}
