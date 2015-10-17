import std.stdio;
import mail.pop3;

void main()
{
	Pop3Reply r;
	
	auto link = new Pop3("localhost");
	r = link.connect;
	writeln(r, r.message);

	r = link.auth("user", "password");
	writeln(r, r.message);

//	r = link.list;
//	writeln(r.code, r.message);

	r = link.stat;

	writeln(r);
	writeln(link.length);

	r = link.retr(1);
	writeln(r.code, r.message);
	
//	auto m = link.retrMsg(1);
//	writeln(m.headers);
//	writeln(m.plain);
//	writeln(m.parts[0].headers);
}
