# Unmaintained


# Mail
Mail is a synchronous POP3/SMTP library for [D programming language](https://dlang.org). It is available as a package in the [dub registry
](https://code.dlang.org/packages/mail)
## Usage

```d
import std.stdio;
import mail.smtp;

void main()
{
	SmtpReply r;
	auto link = new Smtp("localhost");
	r = link.connect;
	writeln(r.success, " ", r);

	r = link.startTLS;
	writeln(r.success, " ", r);

	r = link.helo;
	writeln(r.success, " ", r);
	r = link.ehlo;
	writeln(r.success, " ", r);

	r = link.auth(SmtpAuthType.LOGIN);
	writeln(r.success, " ", r);

	r = link.authLoginUsername("user");
	writeln(r.success, " ", r);

	r = link.authLoginPassword("password");
	writeln(r.success, " ", r);


	r = link.mailFrom("root@localhost");
	writeln(r.success, " ", r);

	r = link.rcptTo("root@localhost");
	writeln(r.success, " ", r);
	
	r = link.data();
	writeln(r.success, " ", r);

	r = link.dataBody("test");
	writeln(r.success, " ", r);

	Msg m;

	m.headers["subject"] = "Test";
	m.data = "Test sdf sdf sd sdf sdfs dfsdf sdfs dfs dfs df sdf sdfs dfdsdfsdsfdsf s  sdfs dfs dfsfsdf";


	Msg m2;
	m2.headers["content-type"] = "text/html";
	m2.data = "<html><body><h1>TEST</h1></body></html>";
	
	m.parts ~= m2;
	
	
	r = link.send("root@localhost", ["root@localhost"], m);
	writeln(r.success, " ", r);


	r = link.quit();
	writeln(r.success, " ", r);

	link.disconnect();
}
```

See [examples](https://github.com/anton-dutov/mail/tree/master/examples) for more usage demo

