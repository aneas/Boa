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
	env.variables["true"] = Reference.RValue(Value.Bool(true));
	env.variables["false"] = Reference.RValue(Value.Bool(false));
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
	env.variables["ffi"] = Reference.RValue(Value.BuiltinFunction((Reference[] args) {
		import std.string;
		import core.sys.posix.dlfcn;

		enum ffi_abi : int {
			FFI_UNIX64 = 2
		}

		enum ffi_status {
			FFI_OK,
			FFI_BAD_TYPEDEF,
			FFI_BAD_ABI
		}

		struct ffi_type {
			size_t size;
			ushort alignment;
			ushort type;
			ffi_type** elements;
		}

		struct ffi_cif {
			ffi_abi abi;
			uint nargs;
			ffi_type** arg_types;
			ffi_type* rtype;
			uint bytes;
			uint flags;
		}

		alias ffi_arg = ulong;

		static void* libffi = null;
		static ffi_type* ffi_type_void;
		static ffi_type* ffi_type_uint8;
		static ffi_type* ffi_type_sint8;
		static ffi_type* ffi_type_uint16;
		static ffi_type* ffi_type_sint16;
		static ffi_type* ffi_type_uint32;
		static ffi_type* ffi_type_sint32;
		static ffi_type* ffi_type_uint64;
		static ffi_type* ffi_type_sint64;
		static ffi_type* ffi_type_float;
		static ffi_type* ffi_type_double;
		static ffi_type* ffi_type_pointer;
		alias ffi_prep_cif_t = extern(C) ffi_status function(ffi_cif* cif, ffi_abi abi, uint nargs, ffi_type *rtype, ffi_type **atypes);
		alias ffi_call_t     = extern(C) void function(ffi_cif *cif, void* fn, void *rvalue, void **avalue);
		static ffi_prep_cif_t ffi_prep_cif;
		static ffi_call_t     ffi_call;

		ffi_type* stringToType(string type) {
			switch(type) {
				case "void":    return ffi_type_void;
				case "uint8":   return ffi_type_uint8;
				case "sint8":   return ffi_type_sint8;
				case "uint16":  return ffi_type_uint16;
				case "sint16":  return ffi_type_sint16;
				case "uint32":  return ffi_type_uint32;
				case "sint32":  return ffi_type_sint32;
				case "uint64":  return ffi_type_uint64;
				case "sint64":  return ffi_type_sint64;
				case "float":   return ffi_type_float;
				case "double":  return ffi_type_double;
				case "pointer": return ffi_type_pointer;
				default:        assert(false);
			}
		}

		if(libffi is null) {
			libffi = dlopen("libffi.so.6", RTLD_LAZY);
			assert(libffi !is null);
			ffi_type_void    = cast(ffi_type*)dlsym(libffi, "ffi_type_void");
			ffi_type_uint8   = cast(ffi_type*)dlsym(libffi, "ffi_type_uint8");
			ffi_type_sint8   = cast(ffi_type*)dlsym(libffi, "ffi_type_sint8");
			ffi_type_uint16  = cast(ffi_type*)dlsym(libffi, "ffi_type_uint16");
			ffi_type_sint16  = cast(ffi_type*)dlsym(libffi, "ffi_type_sint16");
			ffi_type_uint32  = cast(ffi_type*)dlsym(libffi, "ffi_type_uint32");
			ffi_type_sint32  = cast(ffi_type*)dlsym(libffi, "ffi_type_sint32");
			ffi_type_uint64  = cast(ffi_type*)dlsym(libffi, "ffi_type_uint64");
			ffi_type_sint64  = cast(ffi_type*)dlsym(libffi, "ffi_type_sint64");
			ffi_type_float   = cast(ffi_type*)dlsym(libffi, "ffi_type_float");
			ffi_type_double  = cast(ffi_type*)dlsym(libffi, "ffi_type_double");
			ffi_type_pointer = cast(ffi_type*)dlsym(libffi, "ffi_type_pointer");
			ffi_prep_cif     = cast(ffi_prep_cif_t)dlsym(libffi, "ffi_prep_cif");
			ffi_call         = cast(ffi_call_t)dlsym(libffi, "ffi_call");
		}

		static void*[string] libCache;

		assert(args.length >= 1);
		string libName = args[0].value.asString.idup;
		void* handle;
		if(libName in libCache)
			handle = libCache[libName];
		else {
			handle = dlopen(libName.toStringz, RTLD_LAZY);
			libCache[libName] = handle;
		}
		assert(handle);

		assert(args.length >= 2);
		string funcName = args[1].value.asString.idup;
		void* func = dlsym(handle, funcName.toStringz);
		assert(func);

		assert(args.length >= 3);

		ffi_type*[] ffiArgs;
		foreach(arg; args[3 .. $])
			ffiArgs ~= stringToType(arg.value.asString.idup);

		ffi_cif cif;
		auto status = ffi_prep_cif(&cif, ffi_abi.FFI_UNIX64, cast(uint)ffiArgs.length, stringToType(args[2].value.asString.idup), ffiArgs.ptr);
		assert(status == ffi_status.FFI_OK);

		return Reference.RValue(Value.BuiltinFunction(delegate Reference(Reference[] arguments) {
			assert(arguments.length == args.length - 3);
			void*[] values;
			foreach(i, a; arguments) {
				switch(args[3 + i].value.asString) {
					case "pointer":
						ubyte[] buffer;
						a.value.packFFI(buffer);
						auto pointer = new void*;
						*pointer = buffer.ptr;
						values ~= pointer;
						break;

					case "sint32":
						assert(a.value.isInt);
						auto pointer = new int;
						*pointer = a.value.int_;
						values ~= pointer;
						break;

					default:
						assert(false);
				}
			}
			ffi_arg rc;
			ffi_call(&cif, func, &rc, values.ptr);
			// rc now holds the result of the call
			return Reference.RValue(Value.Int(0));
		}));
	}));
	program.execute(env);
}
