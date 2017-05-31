module mail.stmp;

import core.thread;

import std.algorithm;
import std.base64;
import std.conv;
import std.string;
import std.encoding;
import std.uri;

public import mail.msg : Msg;
import mail.socket;

enum SmtpAuthType
{
    PLAIN = 0,
    LOGIN,
};

enum SmtpReplyCode : ushort
{
    HELP_STATUS = 211, // Information reply
    HELP = 214, // Information reply

    ready = 220, // After connection is established
    QUIT = 221, // After connected aborted
    AUTH_SUCCESS = 235, // Authentication succeeded
    OK = 250, // Transaction success
    FORWARD = 251, // Non-local user, message is forwarded
    VRFY_FAIL = 252, // Verification failed (still attempt to deliver)

    AUTH_CONTINUE = 334, // Answer to AUTH <method> prompting to send auth data
    DATA_START = 354, // Server starts to accept mail data

    NA = 421, // Not Available. Shutdown must follow after this reply
    NEED_PASSWORD = 435, // Password transition is needed
    BUSY = 450, // Mail action failed
    ABORTED = 451, // Action aborted (internal server error)
    STORAGE = 452, // Not enough system storage on server
    TLS = 454, // TLS unavailable | Temporary Auth fail

    SYNTAX = 500, // Command syntax error | Too long auth command line
    SYNTAX_PARAM = 501, // Command parameter syntax error
    NI = 502, // Command not implemented
    BAD_SEQUENCE = 503, // This command breaks specified allowed sequences
    NI_PARAM = 504, // Command parameter not implemented

    AUTH_REQUIRED = 530, // Authentication required
    AUTH_TOO_WEAK = 534, // Need stronger authentication type
    AUTH_CRED = 535, // Wrong authentication credentials
    AUTH_ENCRYPTION = 538, // Encryption reqiured for current authentication type

    MAILBOX = 550, // Mailbox is not found (for different reasons)
    TRY_FORWARD = 551, // Non-local user, forwarding is needed
    MAILBOX_STORAGE = 552, // Storage for mailbox exceeded
    MAILBOX_NAME = 553, // Unallowed name for the mailbox
    FAIL = 554 // Transaction fail
};

struct SmtpReply
{
    bool   success;
    ushort code;
    string message;

    void toString(scope void delegate(const(char)[]) sink) const
    {
        sink(code.to!string);
        sink(message);
    }
};

unittest
{
    auto reply = SmtpReply(true, 220, "-Test\r\n");
    assert(reply.to!string == "220-Test\r\n");
}

class Smtp
{
    private
    {
        Socket _sock;
    }

    this(in string host, in ushort port = 25)
    {
        _sock = new Socket(host, port);
    }

    SmtpReply connect()
    {
        SmtpReply r;
        if (_sock.connect())
        {
            r = parseReply(receiveAll);
        }
        return r;
    }

    void disconnect()
    {
        _sock.disconnect();
    }

    SmtpReply startTLS(EncryptionMethod encMethod = EncryptionMethod.TLSv1_2)
    {
        auto r = query("STARTTLS");
        if (r.success)
        {
            r.success = _sock.SSLbegin(encMethod);
        }
        return r;
    }

    SmtpReply noop()
    {
        return query("NOOP");
    }

    SmtpReply data()
    {
        return query("data");
    }

    SmtpReply helo()
    {
        return query("HELO " ~ _sock.hostName);
    }

    SmtpReply ehlo()
    {
        return query("EHLO " ~ _sock.hostName);
    }

    SmtpReply auth(in SmtpAuthType authType)
    {
        return query("AUTH " ~ authType.to!string);
    }

    SmtpReply authPlain(in string login, in string password)
    {
        return query(Base64.encode(cast(ubyte[])(login ~ "\0" ~ login ~ "\0" ~ password)));
    }

    SmtpReply authLoginUsername(string username)
    {
        return query(Base64.encode(cast(ubyte[]) username));
    }

    SmtpReply authLoginPassword(string password)
    {
        return query(Base64.encode(cast(ubyte[]) password));
    }

    SmtpReply mailFrom(in string addr)
    {
        return query("MAIL FROM: <" ~ addr ~ ">");
    }

    SmtpReply rcptTo(in string addr)
    {
        return query("RCPT TO: <" ~ addr ~ ">");
    }

    SmtpReply dataBody(in string data)
    {
        return query(data ~ "\r\n.");
    }

    SmtpReply send(in string fromAddr, in string[] toAddr, Msg msg)
    {
        if (!toAddr.length)
            return SmtpReply(false);

        auto r = mailFrom(fromAddr);

        msg.headers["from"] = fromAddr;

        if (r.success)
        {
            foreach (i; toAddr)
            {
                r = rcptTo(i);
                if (!r.success)
                    break;

                msg.headers.add("to", i);
            }
            if (r.success)
            {
                r = data();
            }
            if (r.success)
            {
                r = dataBody(msg.to!string);
            }
        }
        return r;
    }

    SmtpReply quit()
    {
        return query("quit");
    }

private:
    SmtpReply parseReply(string data)
    {
        auto reply = SmtpReply(true, data[0 .. 3].to!ushort, data[3 .. $].idup);
        if (reply.code >= 400)
        {
            reply.success = false;
        }
        return reply;
    }

    SmtpReply query(string command)
    {
        if (!_sock.isOpen)
            return SmtpReply(false);
        _sock.send(command ~ "\r\n");
        return parseReply(receiveAll);
    }

    string receiveAll()
    {
        string tmp;
        string data;
        do
        {
            tmp = _sock.receive();
            data ~= tmp;
        }
        while (tmp.length && !data.endsWith("\n"));
        return data;
    }
}
