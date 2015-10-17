module mail.headers;

import std.conv;
import std.algorithm;
import std.string;
import std.array;

debug  import std.stdio;

enum maxLen = 78;

string norm(string)(string key)
{
	return map!("a.capitalize()")(key.split("-")).join("-");
}

struct Headers
{
	private
	{
		struct Header
		{
			string key;
			string value;
		}
		Header[] _headers;
	}

	this(in Headers rsh)
	{
		_headers ~= rsh._headers.idup;
	}

	string[] all(string key) const pure
	{
		auto nKey = key.norm;
		string[] result;
		foreach(h; _headers)
		{
			if (h.key == nKey)
			{
				result ~= h.value;
			}
		}
		return result;
	}

	void update(string[string] values) pure
	{
		foreach(k, ref v; values)
		{
			opIndexAssign(v, k);
		}
	}

	string opIndex(string key) pure const
	{
		auto nKey = key.norm;
		auto val  = "";
		foreach(h; _headers)
		{
			if (h.key == nKey)
			{
				val = h.value;
				break;
			}
		}
		return val;
	}

	string get(string key, lazy string defVal = null) pure const
	{
		auto nKey = key.norm;
		foreach(h; _headers)
		{
			if (h.key == nKey)
			{
				return h.value;
			}
		}
		return defVal;
	}

	void opIndexAssign(ulong val, string key) pure
	{
		opIndexAssign(to!string(val), key);
	}

	void opIndexAssign(string[] val, string key) pure
	{
		opIndexAssign(val.join(","), key);
	}

	void opIndexAssign(string val, string key) pure
	{
		auto nKey = key.norm;
		foreach(h; _headers)
		{
			if (h.key == nKey)
			{
				h.value = val;
				return;
			}
		}
		_headers ~= Header(nKey, val);
	}

	void add(string key, string val) pure
	{
		_headers ~= Header(key.norm, val);
	}

	void toString(scope void delegate(const(char)[]) sink) const
	{
		foreach (item; _headers)
		{
			// TODO: Folding
			sink(item.key);
			sink(": ");
			sink(item.value);
			sink("\r\n");
		}
		sink("\r\n");
	}

	void parse(string data) pure
	{
		string   key;
		string[] val;
		void save()
		{
			add(key, val.join(" "));
			val.length = 0;
		}
		auto lines = data.split("\n");
		while (lines.length)
		{
			auto tmp = lines.front.strip.findSplit(":");
			key  = tmp[0];
			val ~= tmp[2].strip;
			lines.popFront;
			while(lines.length && (lines.front.startsWith("\t") || lines.front.startsWith(" ")))
			{
				val ~= lines.front.strip;
				lines.popFront;
			}
			save();
		}
	}
}


unittest
{
	Headers h;
	
	h["key1"] = "val1";
	h["key2"] = "val2";
	
	assert(h.get("key1") == "val1");
	assert(h["key2"] == "val2");
	
	h.add("key2", "val2_2");
	assert(h["key2"] == "val2");
	assert(h.all("key2") == ["val2", "val2_2"]);
	
}