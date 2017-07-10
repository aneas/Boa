module boa.statements;


import boa.expressions;
import boa.runtime;
import boa.values;


abstract class Statement {
	abstract Action execute(Environment env);
}


final class FunctionDeclaration : Statement {
	string    name;
	string[]  parameters;
	Statement body_;
	this(string name, string[] parameters, Statement body_) {
		this.name       = name;
		this.parameters = parameters;
		this.body_      = body_;
	}
	override Action execute(Environment env) {
		Reference[string] closure;
		foreach(name, value; env.variables)
			closure[name] = value;

		env.variables[name] = Reference.RValue(Value.Function(parameters, closure, body_));
		env.variables[name].rvalue.function_.closure[name] = env.variables[name]; // add self to support recursion
		return Action.Proceed;
	}
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


final class VarStatement : Statement {
	string identifier;
	Expression value;
	this(string identifier, Expression value) {
		this.identifier = identifier;
		this.value      = value;
	}
	override Action execute(Environment env) {
		auto value = (this.value !is null ? this.value.evaluate(env).value : Value.Int(0));
		env.variables[identifier] = Reference.LValue(value);
		return Action.Proceed;
	}
}


final class IfStatement : Statement {
	Expression condition;
	Statement then_, else_;
	this(Expression condition, Statement then_, Statement else_) {
		this.condition = condition;
		this.then_     = then_;
		this.else_     = else_;
	}
	override Action execute(Environment env) {
		auto c = condition.evaluate(env).value;
		assert(c.isBool);
		if(c.bool_)
			return then_.execute(env);
		else if(else_ !is null)
			return else_.execute(env);
		else
			return Action.Proceed;
	}
}


final class WhileStatement : Statement {
	Expression condition;
	Statement body_;
	this(Expression condition, Statement body_) {
		this.condition = condition;
		this.body_     = body_;
	}
	override Action execute(Environment env) {
		while(true) {
			auto c = condition.evaluate(env).value;
			assert(c.isBool);
			if(c.bool_) {
				auto action = body_.execute(env);
				if(action.isReturn)
					return action;
			}
			else
				return Action.Proceed;
		}
	}
}


final class BlockStatement : Statement {
	Statement[] statements;
	this(Statement[] statements) {
		this.statements = statements;
	}
	override Action execute(Environment env) {
		foreach(statement; statements) {
			auto action = statement.execute(env);
			if(action.isReturn)
				return action;
		}
		return Action.Proceed;
	}
}
