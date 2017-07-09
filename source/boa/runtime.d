module boa.runtime;


import boa.values;


final class Environment {
	Reference[string] variables;
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
