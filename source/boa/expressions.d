module boa.expressions;


import boa.runtime;
import boa.values;


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


final class DoubleLiteral : Expression {
	double value;
	this(double value) {
		this.value = value;
	}
	override Reference evaluate(Environment env) {
		return Reference.RValue(Value.Double(value));
	}
}


final class StringLiteral : Expression {
	string value;
	this(string value) {
		this.value = value;
	}
	override Reference evaluate(Environment env) {
		Value[] chars;
		foreach(char c; value)
			chars ~= Value.Char(c);
		return Reference.RValue(Value.Array(chars));
	}
}


final class ArrayLiteral : Expression {
	Expression[] elements;
	this(Expression[] elements) {
		this.elements = elements;
	}
	override Reference evaluate(Environment env) {
		Value[] es;
		foreach(element; elements)
			es ~= element.evaluate(env).value;
		return Reference.RValue(Value.Array(es));
	}
}


final class Variable : Expression {
	string name;
	this(string name) {
		this.name = name;
	}
	override Reference evaluate(Environment env) {
		assert(name in env.variables, name);
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
			foreach(name, value; f.function_.closure)
				localEnv.variables[name] = value;
			foreach(i, parameter; f.function_.parameters)
				localEnv.variables[parameter] = args[i];
			auto action = f.function_.body_.execute(localEnv);
			if(action.isReturn)
				return action.returnValue;
			else
				return Reference.RValue(Value.Int(0));
		}
		else if(f.isBuiltinFunction)
			return f.builtinFunction(args);
		else
			assert(false);
	}
}


final class Assignment : Expression {
	Expression left, right;
	this(Expression left, Expression right) {
		this.left  = left;
		this.right = right;
	}
	override Reference evaluate(Environment env) {
		auto l = left.evaluate(env);
		assert(l.isLValue);
		auto r = right.evaluate(env);
		l.lvalue.assign(r.value);
		return r;
	}
}


final class IndexExpression : Expression {
	Expression expression, index;
	this(Expression expression, Expression index) {
		this.expression = expression;
		this.index      = index;
	}
	override Reference evaluate(Environment env) {
		auto l = expression.evaluate(env);
		assert(l.value.isArray);

		auto r = index.evaluate(env).value;
		assert(r.isInt);
		assert(r.int_ >= 0);
		assert(r.int_ < l.value.arrayElements.length);

		if(l.isLValue)
			return Reference.LValue(l.value.arrayElements[r.int_]);
		else
			return Reference.RValue(l.value.arrayElements[r.int_]);
	}
}
