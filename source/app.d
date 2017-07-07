import std.conv;
import std.stdio;

final class Value {
	enum Tag { Bool, Int }
	Tag tag;
	union {
		bool bool_;
		int  int_;
	}
	static Value Bool(bool value) { auto v = new Value; v.tag = Tag.Bool; v.bool_ = value; return v; }
	static Value Int (int  value) { auto v = new Value; v.tag = Tag.Int ; v.int_  = value; return v; }
	bool isBool() const { return (tag == Tag.Bool); }
	bool isInt () const { return (tag == Tag.Int ); }
	override string toString() const {
		final switch(tag) with(Tag) {
			case Bool: return (bool_ ? "true" : "false");
			case Int:  return int_.to!string;
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
	abstract Reference evaluate();
}

final class IntLiteral : Expression {
	int value;
	this(int value) {
		this.value = value;
	}
	override Reference evaluate() {
		return Reference.RValue(Value.Int(value));
	}
}

final class AddExpression : Expression {
	Expression left, right;
	this(Expression left, Expression right) {
		this.left  = left;
		this.right = right;
	}
	override Reference evaluate() {
		auto l = left.evaluate().value;
		auto r = right.evaluate().value;
		assert(l.isInt);
		assert(r.isInt);
		return Reference.RValue(Value.Int(l.int_ + r.int_));
	}
}

void main() {
	auto expression = new AddExpression(new IntLiteral(19), new IntLiteral(23));
	auto result     = expression.evaluate();
	writeln(result.value);
}
