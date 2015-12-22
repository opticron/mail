module mail.socket;

import std.conv: to;
import std.socket;

import deimos.openssl.conf;
import deimos.openssl.err;
import deimos.openssl.ssl;

enum EncryptionMethod : uint
{
	None,    // No encryption is used
//	SSLv23,  // SSL version 3 but rollback to 2
//	SSLv3,   // SSL version 3 encryption
	TLSv1,   // TLS version 1 encryption
	TLSv1_1, // TLS version 1.1 encryption
	TLSv1_2, // TLS version 1.2 encryption
}

class Socket
{
	private
	{
		bool		_open;
		string      _host;
		ushort      _port;
		TcpSocket   _sock;
		char[4096]  _buff;

		bool        _secure;
		bool        _verified;

		SSL_METHOD  *_sslMethod;
		SSL_CTX     *_sslCtx;
		SSL         *_ssl;
		X509        *_x509;
	}

public:
	@property bool isOpen() const
	{
		return _open;
	}
	@property bool isSecure() const
	{
		return _secure;
	}
	@property bool isCertVerified() const
	{
		return _verified;
	}

	@property string hostName() const
	{
		return _sock.hostName;
	}
public:
	this(string host, ushort port)
	{
		_host = host;
		_port = port;
		_sock = new TcpSocket();
	}
	~this()
	{
		SSLEnd();
	}

	bool connect()
	{
		try
		{
			auto ai = getAddress(_host, _port);
			if (ai.length)
			{
				_sock.connect(ai[0]);
				return _open = true;
			}
		}
		catch
		{
		}
		return false;
	}

	void disconnect()
	{
		if (_sock !is null)
		{
			_open = false;
			_sock.shutdown(SocketShutdown.BOTH);
			_sock.close();
		}
	}

	bool SSLbegin(EncryptionMethod encMethod = EncryptionMethod.TLSv1_2)
	{
		import std.stdio;
		// Init
		OPENSSL_config("");
		SSL_library_init();
		SSL_load_error_strings();

		final switch (encMethod)
		{
//			case EncryptionMethod.SSLv23:
//				_sslMethod = cast(SSL_METHOD*) SSLv23_client_method();
//				break;
//			case EncryptionMethod.SSLv3:
//				_sslMethod = cast(SSL_METHOD*) SSLv3_client_method();
//				break;
			case EncryptionMethod.TLSv1:
				_sslMethod = cast(SSL_METHOD*) TLSv1_client_method();
				break;
			case EncryptionMethod.TLSv1_1:
				_sslMethod = cast(SSL_METHOD*) TLSv1_2_client_method();
				break;
			case EncryptionMethod.TLSv1_2:
				_sslMethod = cast(SSL_METHOD*) TLSv1_2_client_method();
				break;
			case EncryptionMethod.None:
				return false;
		}
		
		_sslCtx = SSL_CTX_new(cast(const(SSL_METHOD*)) (_sslMethod));
		if (_sslCtx is null)
			return false;

		// Stream
		_ssl = SSL_new(_sslCtx);
		if (_ssl is null)
			return false;


		SSL_set_fd(_ssl, _sock.handle);

		// Handshake
		if (SSL_connect(_ssl) != 1)
			return false;

		_x509 = SSL_get_peer_certificate(_ssl);

		if (_x509 is null)
			return false;

		_secure = true;

		// Verify
		if (SSL_get_verify_result(_ssl) != X509_V_OK)
		{
			_verified = false;
		}
		else
		{
			_verified = true;
		}
		return _secure;
	}

	void SSLEnd()
	{
		if (_secure)
		{
			_secure = false;
			SSL_shutdown(_ssl);
		}

		if (_x509 !is null)
		{
			X509_free(_x509);
			_x509 = null;
		}

		if (_ssl !is null)
		{
			SSL_free(_ssl);
			_ssl = null;
		}

		if (_sslCtx !is null)
		{
			SSL_CTX_free(_sslCtx);
			_sslCtx = null;
		}
	}

	bool send(string data)
	{
		if (_secure)
		{
			return SSL_write(_ssl, data.ptr, data.length.to!int) >= 0;
		}
		return _sock.send(data) == data.length;
	}

	string receive()
	{
		int len;
		if (_secure)
		{
			len = SSL_read(_ssl, _buff.ptr, _buff.length);
			if (len < 0)
			{
				len = 0;
			}
		}
		else
		{
			len = cast(int) _sock.receive(_buff);
		}
		return _buff[0 .. len].to!string;
	}
}