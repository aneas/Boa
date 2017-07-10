module boa.parser;


import std.algorithm : canFind;
import std.array;
import std.ascii : isDigit;
import std.uni : isAlpha;

import boa.expressions;
import boa.program;
import boa.statements;


struct Token {
	enum Type { Whitespace, LineComment, Operator, Delimiter, Keyword, Identifier, Integer, String, Eof }
	Type   type;
	string value;
	bool opEquals(Type t) const { return (type == t); }
	bool opEquals(string s) const { return (value == s); }
}


Token fetchToken(ref string s, size_t length, Token.Type type) {
	auto value = s[0 .. length];
	s = s[length .. $];
	return Token(type, value);
}


Token fetchToken(ref string s) {
	static Keywords = ["else", "function", "if", "return", "while"];

	if(s.empty)
		return Token(Token.Type.Eof, s);

	switch(s[0]) {
		case ' ': case '\t': case '\r': case '\n':
			size_t length = 1;
			while(length < s.length && (s[length] == ' ' || s[length] == '\t' || s[length] == '\r' || s[length] == '\n'))
				length++;
			return s.fetchToken(length, Token.Type.Whitespace);

		case ',': case ';': case '[': case ']': case '(': case ')': case '{': case '}':
			return s.fetchToken(1, Token.Type.Delimiter);

		case '+': case '*': case '=': case '!':
			size_t length = 1;
			while(length < s.length && (s[length] == '+' || s[length] == '*' || s[length] == '=' || s[length] == '!'))
				length++;
			return s.fetchToken(length, Token.Type.Operator);

		case '/':
			assert(s.length >= 2);
			assert(s[1] == '/');
			size_t length = 2;
			while(length < s.length && s[length] != '\n')
				length++;
			return s.fetchToken(length, Token.Type.LineComment);

		case '"':
			size_t length = 1;
			while(length < s.length && s[length] != '"') {
				if(s[length] == '\\' && length + 1 < s.length)
					length += 2;
				else
					length++;
			}
			assert(length < s.length);
			assert(s[length] == '"');
			length++;
			return s.fetchToken(length, Token.Type.String);

		default:
			if(s[0].isAlpha) {
				size_t length = 1;
				while(length < s.length && (s[length].isAlpha || s[length].isDigit || s[length] == '_'))
					length++;
				if(Keywords.canFind(s[0 .. length]))
					return s.fetchToken(length, Token.Type.Keyword);
				else
					return s.fetchToken(length, Token.Type.Identifier);
			}
			else if(s[0].isDigit) {
				size_t length = 1;
				while(length < s.length && s[length].isDigit)
					length++;
				return s.fetchToken(length, Token.Type.Integer);
			}
			else
				assert(false);
	}
}


Token peekToken(string s) {
	return s.fetchToken();
}


void skipToken(ref string s) {
	s.fetchToken();
}


Token peekTokenAfterWhitespace(string s) {
	s.skipWhitespace();
	return s.peekToken();
}


void skipWhitespace(ref string s) {
	while(s.peekToken == Token.Type.Whitespace || s.peekToken == Token.Type.LineComment)
		s.skipToken();
	while(!s.empty) {
		if(s[0] == ' ' || s[0] == '\t' || s[0] == '\r' || s[0] == '\n')
			s.popFront();
		else
			break;
	}
}


Program parseProgram(string s) {
	Statement[] statements;
	s.skipWhitespace();
	while(!s.empty) {
		auto statement = s.parseStatement();
		statements ~= statement;
		s.skipWhitespace();
	}
	return new Program(statements);
}


Statement parseStatement(ref string s) {
	if(s.peekToken == "{") {
		s.skipToken();
		s.skipWhitespace();
		Statement[] statements;
		while(s.peekToken != "}") {
			statements ~= s.parseStatement();
			s.skipWhitespace();
		}
		assert(s.peekToken == "}");
		s.skipToken();
		return new BlockStatement(statements);
	}
	else if(s.peekToken == "function") {
		s.skipToken();
		s.skipWhitespace();
		assert(s.peekToken == Token.Type.Identifier);
		auto name = s.peekToken().value;
		s.skipToken();
		s.skipWhitespace();
		assert(s.peekToken == "(");
		s.skipToken();
		s.skipWhitespace();
		string[] parameters;
		if(s.peekToken != ")") {
			assert(s.peekToken == Token.Type.Identifier);
			parameters ~= s.peekToken.value;
			s.skipToken();
			s.skipWhitespace();
			while(s.peekToken == ",") {
				s.skipToken();
				s.skipWhitespace();
				assert(s.peekToken == Token.Type.Identifier);
				parameters ~= s.peekToken.value;
				s.skipToken();
				s.skipWhitespace();
			}
		}
		assert(s.peekToken == ")");
		s.skipToken();
		s.skipWhitespace();
		assert(s.peekToken == "{");
		s.skipToken();
		s.skipWhitespace();
		auto body_ = s.parseStatement();
		s.skipWhitespace();
		assert(s.peekToken == "}");
		s.skipToken();
		return new FunctionDeclaration(name, parameters, body_);
	}
	else if(s.peekToken == "return") {
		s.skipToken();
		s.skipWhitespace();
		auto expression = s.parseExpression();
		s.skipWhitespace();
		assert(s.peekToken == ";");
		s.skipToken();
		return new ReturnStatement(expression);
	}
	else if(s.peekToken == "if") {
		s.skipToken();
		s.skipWhitespace();
		assert(s.peekToken == "(");
		s.skipToken();
		s.skipWhitespace();
		auto condition = s.parseExpression();
		s.skipWhitespace();
		assert(s.peekToken == ")");
		s.skipToken();
		s.skipWhitespace();
		auto then_ = s.parseStatement();
		Statement else_ = null;
		if(s.peekTokenAfterWhitespace == "else") {
			s.skipWhitespace();
			s.skipToken();
			s.skipWhitespace();
			else_ = s.parseStatement();
		}
		return new IfStatement(condition, then_, else_);
	}
	else if(s.peekToken == "while") {
		s.skipToken();
		s.skipWhitespace();
		assert(s.peekToken == "(");
		s.skipToken();
		s.skipWhitespace();
		auto condition = s.parseExpression();
		s.skipWhitespace();
		assert(s.peekToken == ")");
		s.skipToken();
		s.skipWhitespace();
		auto body_ = s.parseStatement();
		return new WhileStatement(condition, body_);
	}
	else if(s.peekToken == "var") {
		s.skipToken();
		s.skipWhitespace();
		auto token = s.fetchToken();
		assert(token == Token.Type.Identifier);
		s.skipWhitespace();
		assert(s.peekToken == ";");
		s.skipToken();
		return new VarStatement(token.value);
	}
	else {
		auto expression = s.parseExpression();
		s.skipWhitespace();
		assert(s.peekToken == ";", s);
		s.skipToken();
		return new ExpressionStatement(expression);
	}
}


Expression parseExpression(ref string s) {
	auto expression = s.parseOperand();
	while(s.peekTokenAfterWhitespace == Token.Type.Operator) {
		s.skipWhitespace();
		auto operator = s.fetchToken.value;
		s.skipWhitespace();
		auto right = s.parseOperand();
		if(operator == "=")
			expression = new Assignment(expression, right);
		else
			expression = new FunctionCall(new Variable(operator), [expression, right]);
	}
	return expression;
}


Expression parseOperand(ref string s) {
	auto expression = s.parsePrimary();
	while(true) {
		if(s.peekTokenAfterWhitespace == "[") {
			s.skipWhitespace();
			s.skipToken();
			s.skipWhitespace();
			auto index = s.parseExpression();
			assert(s.peekToken == "]");
			s.skipToken();
			expression = new IndexExpression(expression, index);
		}
		else if(s.peekTokenAfterWhitespace == "(") {
			s.skipWhitespace();
			s.skipToken();
			Expression[] arguments;
			if(s.peekToken != ")") {
				arguments ~= s.parseExpression();
				s.skipWhitespace();
				while(s.peekToken == ",") {
					s.skipToken();
					s.skipWhitespace();
					arguments ~= s.parseExpression();
					s.skipWhitespace();
				}
			}
			assert(s.peekToken == ")");
			s.skipToken();
			expression = new FunctionCall(expression, arguments.dup);
		}
		else
			break;
	}
	return expression;
}


Expression parsePrimary(ref string s) {
	if(s.peekToken == Token.Type.Identifier)
		return new Variable(s.fetchToken.value);
	else if(s.peekToken == Token.Type.Integer) {
		int value = 0;
		foreach(c; s.fetchToken.value)
			value = value * 10 + (c - '0');
		return new IntLiteral(value);
	}
	else if(s.peekToken == "[") {
		s.skipToken();
		s.skipWhitespace();
		Expression[] elements;
		if(s.peekToken != "]") {
			elements ~= s.parseExpression();
			s.skipWhitespace();
			while(s.peekToken == ",") {
				s.skipToken();
				s.skipWhitespace();
				elements ~= s.parseExpression();
				s.skipWhitespace();
			}
		}
		assert(s.peekToken == "]");
		s.skipToken();
		return new ArrayLiteral(elements);
	}
	else if(s.peekToken == "(") {
		s.skipToken();
		s.skipWhitespace();
		auto expression = s.parseExpression();
		s.skipWhitespace();
		assert(s.peekToken == ")");
		s.skipToken();
		return expression;
	}
	else if(s.peekToken == Token.Type.String) {
		auto token = s.fetchToken();
		assert(token.value.length >= 2);
		return new StringLiteral(token.value[1 .. $ - 1]);
	}
	else
		assert(false);
}
