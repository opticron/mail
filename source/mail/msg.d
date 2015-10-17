module mail.msg;

public import mail.headers: Headers;

import mail.utils;

import std.algorithm;
import std.array: replace;
import std.conv: to;
import std.base64: Base64;
import std.uri: decode;
import std.string;
import std.uuid: randomUUID;

struct Msg
{
	Headers headers;
	string  data;
	Msg[]	parts;
	ubyte[] rawData;

	@property string plain() const
	{	
		string content;
		if (data.length)
		{
			content = data;
		} else {
			foreach(ref m; parts)
			{
				if (!m.headers.all("content-type").length
				 ||  m.headers["content-type"].toLower.startsWith("text/plain"))
				{
					content = m.data;
					break;
				}
			}
		}
		return content;
	}

	void toString(scope void delegate(const(char)[]) sink) const
	{
		Headers hM = Headers(headers);
		Headers hS;

		auto boundary = randomUUID.to!string;
		
		void _pack(char[] d)
		{
			d = Base64.encode(cast(ubyte[]) d);
			while (d.length)
			{
				auto m = min(76, d.length);
				sink(d[0 .. m] ~ "\r\n");
				if (m == d.length)
					break;
				d = d[m .. $];
			}
		}

		if (parts.length)
		{
			hS["content-type"] = hM.get("content-type", "text/plain");
			hM["content-type"] = format("multipart/mixed; boundary=\"%s\"", boundary).dup;
			sink(hM.to!string);
			sink("--" ~ boundary ~ "\r\n");
			hS["content-transfer-encoding"] = "base64";
			
			sink(hS.to!string);
		}
		else
		{
			hM["content-transfer-encoding"] = "base64";
			sink(hM.to!string);
		}

		_pack(data.dup);

		foreach(i; parts)
		{
			sink("--" ~ boundary ~ "\r\n");
			sink(i.to!string);
		}
		if (parts.length)
		{
			sink("--" ~ boundary ~ "--\r\n");
		}
	}

	static Msg parse(ubyte[] srcData)
	{
		Msg m;
		auto tmp = srcData.findSplit(['\r','\n','\r','\n']);
		m.headers.parse(cast(string) tmp[0]);
		auto data = tmp[2];
		auto ct   = m.headers.all("content-type").length ? m.headers["content-type"] : ""; 
		auto enc  = m.headers.all("content-transfer-encoding").length ? m.headers["content-transfer-encoding"].toLower : "";

		//	Transfer encoding
		switch(enc)
		{
			case "quoted-printable":
				data = data.removeAll(['=','\r','\n']);
				data = data.fromPercentEncoding('=');
				break;
			case "base64":
				data = Base64.decode(data.removeAll('\r').removeAll('\n'));
				break;
			default:
		}

		if (!ct.length)
		{
			m.data = (cast(char[]) data).to!string;
		}
		else if (ct.toLower.startsWith("multipart/related")
			 ||  ct.toLower.startsWith("multipart/alternative")
			 ||  ct.toLower.startsWith("multipart/mixed"))
		{
			auto boundary = m.headers["content-type"].findSplit("boundary=")[2];
			if (boundary[0] == '"')
			{
				boundary = boundary[1 .. $ - 1];
			}
			foreach(part; (cast(string) data).split("--" ~ boundary)[1 .. $])
			{
				if (part == "--")
					break;
				m.parts ~= Msg.parse(cast(ubyte[]) part.strip);
			}
		}
		else
		{
			auto charset = m.headers["content-type"].findSplitAfter("charset=")[1].toUpper;
			if (charset[0] == '"')
			{
				charset = charset[1 .. $ - 1];
			}
			switch(charset)
			{
				case "UTF-8":
					m.data = to!string(cast(char[]) data);
					break;
				default:
					data = cast(ubyte[]) recode(charset, "UTF-8", cast(char[]) data);
					m.data = to!string(cast(char[]) data);
			}
		}
		return m;
	}
};