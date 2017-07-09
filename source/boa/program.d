module boa.program;


import boa.runtime;
import boa.statements;


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
