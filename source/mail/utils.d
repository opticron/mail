module mail.utils;

import std.algorithm;
import std.conv:   to;
import std.string: toUpper, toStringz;

extern (C) pure nothrow
{
	alias void* iconv_t;

	iconv_t iconv_open(const char* tocode, const char* fromcode);
	size_t  iconv(iconv_t cd, const char** inbuf,  size_t* inbytesleft,
									char** outbuf, size_t* outbytesleft);
	int iconv_close(iconv_t cd);
}

string recode(string f, string t, char[] src)
{
	auto cd = iconv_open(toStringz(t.toUpper), toStringz(f.toUpper));
	if( cast(size_t)(cd) == -1 )
	{
		return to!string(src);
	}
	char[] dst;
	dst.length = src.length * 6;

	auto   src_ptr = cast(char*) src.ptr;
	auto   dst_ptr = cast(char*) dst.ptr;
	size_t src_len = src.length;
	size_t dst_len = dst.length;

	auto r = iconv(cd, &src_ptr, &src_len, &dst_ptr, &dst_len);
	iconv_close(cd);

	if (r == -1)
	{
		return to!string(src);
	}
	return dst[0 .. $ - dst_len].to!string;
}


ubyte[] fromPercentEncoding(ref ubyte[] src, ubyte chr = '%')
{
	ubyte[] dst;
	if (!src.length)
	{
		return dst;
	}
	size_t i   = 0;
	size_t len = src.length;
	int outLen = 0;
	int a, b;
	ubyte c;
	while (i < len) {
		c = src[i];
		if (c == chr && i + 2 < len) {
			a = src[++i];
			b = src[++i];
			if      (a >= '0' && a <= '9') a -= '0';
			else if (a >= 'a' && a <= 'f') a = a - 'a' + 10;
			else if (a >= 'A' && a <= 'F') a = a - 'A' + 10;

			if      (b >= '0' && b <= '9') b -= '0';
			else if (b >= 'a' && b <= 'f') b = b - 'a' + 10;
			else if (b >= 'A' && b <= 'F') b = b - 'A' + 10;
			dst ~= cast(ubyte)((a << 4) | b);
		} else {
			dst ~= c;
		}
		++i;
		++outLen;
	}
	if (outLen != len)
	{
		dst.length = outLen;
	}
	return dst;
}

ubyte[] removeAll(ubyte[] src, ubyte[] val)
{
	ubyte[] dst = src;
	if (!val.length)
	{
		return src;
	}
	ptrdiff_t i = -1;
	do
	{
		i = dst.countUntil(val);
		if (i >= 0)
		{
			foreach(j; 0 .. val.length)
			{
				dst = dst.remove(i);
			}
		}
	} while(i >= 0);
	return dst;
}

ubyte[] removeAll(ubyte[] src, ubyte val)
{
	ubyte[] dst = src;
	ptrdiff_t i = -1;
	do
	{
		i = dst.countUntil(val);
		if (i >= 0)
		{
			dst = dst.remove(i);
		}
	} while(i >= 0);
	return dst;
}
