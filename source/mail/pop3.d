module mail.pop3;

import core.thread;

import std.algorithm;
import std.conv;
import std.string;
import std.encoding;
import std.uri;
import std.exception;
import std.typecons;

import mail.msg;
import mail.socket;

struct Pop3Reply
{
    string code;
    string message;

    @property bool success() const
    {
        return code.startsWith("+OK");
    }

    void toString(scope void delegate(const(char)[]) sink) const
    {
        sink(code);
        sink(" ");
        sink(message);
    }
};

class Pop3
{
    private
    {
        Socket _sock;
        string _lastCode;
        string _lastData;
    }

    @property ulong length()
    {
        if (_sock.isOpen)
        {
            _sock.send("STAT\n");
            if (isOk)
            {
                return (_lastData.split(" ")[0]).to!ulong;
            }
        }
        return 0;
    }

    @property ulong size()
    {
        if (_sock.isOpen)
        {
            _sock.send("STAT\n");
            if (isOk)
            {
                return (_lastData.split(" ")[1]).to!ulong;
            }
        }
        return 0;
    }

    this(string host, ushort port = 110)
    {
        _sock = new Socket(host, port);
    }

    Pop3Reply connect()
    {
        if (_sock.connect())
        {
            parseReply();
            return Pop3Reply(_lastCode, _lastData);
        }
        return Pop3Reply("-ERR");
    }

    void disconnect()
    {
        _sock.disconnect();
    }

    Pop3Reply auth(string username, string password)
    {
        auto r = query("USER " ~ username);
        if (r.success)
        {
            r = query("PASS " ~ password);
        }
        return r;
    }

    Pop3Reply list()
    {
        return query("LIST", true);
    }

    Pop3Reply stat()
    {
        return query("STAT");
    }

    Pop3Reply noop()
    {
        return query("NOOP");
    }

    Pop3Reply rset()
    {
        return query("RSET");
    }

    Pop3Reply retr(ulong id)
    {
        return query("RETR " ~ id.to!string, true);
    }

    Msg retrMsg(ulong id, bool canonize = true)
    {
        Msg m;
        _sock.send("RETR " ~ id.to!string ~ "\n");
        parseReply(true);
        if (_lastCode.startsWith("+OK"))
        {
            auto mData = _lastData.findSplit("\n")[2].strip;
            if (canonize)
            {
                mData = mData.replace("\n..", "\n.");
            }
            import std.stdio;

            m = Msg.parse(cast(ubyte[]) mData);
        }
        return m;
    }

    Headers getHeaders(ulong id)
    {
        _sock.send("TOP " ~ id.to!string ~ " 0\n");
        parseReply(true);

        auto mData = _lastData.findSplit("\n")[2].strip;
        mData = mData.replace("\n..", "\n.");

        Msg m = Msg.parse(cast(ubyte[]) mData);
        return m.headers;
    }

    Tuple!(ulong, string)[] getUIDLs()
    {
        import std.array : array;

        query("UIDL", true);
        if (!_lastCode.startsWith("+OK"))
            return [];
        return _lastData.split("\r\n").filter!(s => s.length > 2).map!((s) {
            auto a = s.split(" ");
            return tuple(a[0].to!ulong, a[1]);
        }).array;
    }

    Pop3Reply dele(ulong id)
    {
        return query("DELE " ~ id.to!string);
    }

    Pop3Reply quit()
    {
        return query("QUIT");
    }

private:
    void parseReply(bool multiline = false)
    {
        auto tmp = recvAll(multiline).findSplit(multiline ? "\r\n" : " ");
        _lastCode = tmp[0];
        _lastData = tmp[2];
    }

    bool isOk()
    {
        parseReply();
        return _lastCode == "+OK";
    }

    Pop3Reply query(string command, bool multiline = false)
    {
        if (!_sock.isOpen)
            return Pop3Reply("-ERR");
        _sock.send(command ~ "\n");
        parseReply(multiline);
        return Pop3Reply(_lastCode, _lastData);
    }

    string recvAll(bool multiline = false)
    {
        string end = multiline ? "\r\n.\r\n" : "\r\n";
        string result;
        ptrdiff_t cnt = 0;
        do
        {
            auto tmp = _sock.receive();
            if (!tmp.length)
                break;
            result ~= tmp;
            Thread.sleep(dur!"msecs"(1));
        }
        while (!result.endsWith(end));

        if (!result.length)
            return result;

        return result[0 .. $ - end.length];
    }
}

unittest
{
    auto reply = Pop3Reply("+OK", "Test\r\n");
    assert(reply.to!string == "+OK Test\r\n");
}
