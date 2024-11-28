package cj_ftp.connection

import std.collection.*
import std.socket.*
import std.io.*
import std.time.*
import std.net.*
import net.tls.*
import cj_ftp.exception.*

/**
* Schedule Ftp connections
*/
public class FtpConnection <: Resource {

    private var socket: StreamingSocket
    public var reader: FtpStreamReader 
    public var writer: FtpStreamWriter

    public init(socket: StreamingSocket) {
        this.socket = socket
        this.reader = FtpStreamReader(socket)
        this.writer = FtpStreamWriter(socket)
    }

    public func startTls() {
        var config = TlsClientConfig()
        config.verifyMode = TrustAll
        let socket = TlsSocket.client(this.socket, clientConfig: config)
        socket.handshake()
        this.socket = socket
        this.reader = FtpStreamReader(this.socket)
        this.writer = FtpStreamWriter(this.socket)
    }

    public func flush() {
        socket.flush()
    }

    public func disconnect() {
        close()
    }

    public func isClosed(): Bool {
        socket.isClosed()
    }

    public func close() {
        socket.close()
    }

    public func tlsSession(): TlsSession {
        (socket as TlsSocket)
            .getOrThrow({=>FtpConnectionException("not tls socket")})
            .session
            .getOrThrow({=>FtpConnectionException("not tls session")})
    }
}

/**
* Read input stream, add buffer, read by character, read by line
*/
public class FtpStreamReader {
    
    private var readBuff = Array<Byte>(8192, {_=>0})
    private var writeToBuffPosition = 0
    private var readToBuffPosition = 0
    private var inputStream: InputStream

    public init(socket: InputStream) {
        this.inputStream = socket
    }

    /**
    * Read line from input stream, return None if eofß
    */
    public func readln(): ?String {
        let builder = ArrayList<Byte>()
        while (true) {
            let idx = readBuff[readToBuffPosition..writeToBuffPosition].indexOf("\n".toArray()[0])
            match (idx) {
                case Some(idx) =>
                    builder.appendAll(readBuff[readToBuffPosition..(readToBuffPosition + idx + 1)])
                    readToBuffPosition = readToBuffPosition + idx + 1
                    var i = 0
                    while (readToBuffPosition < writeToBuffPosition) {
                        readBuff[i] = readBuff[readToBuffPosition]
                        readToBuffPosition += 1
                        i += 1
                    }
                    writeToBuffPosition = i
                    readToBuffPosition = 0
                    @When[cjc_version >= "0.57.3"]
                    let str = String.fromUtf8(builder.toArray()).trimEnd("\n").trimEnd("\r")
                    @When[cjc_version < "0.57.3"]
                    let str = String.fromUtf8(builder.toArray()).trimRight("\n").trimRight("\r")
                    return str
                case None =>
                    builder.appendAll(readBuff[readToBuffPosition..writeToBuffPosition])
                    readToBuffPosition = 0
                    writeToBuffPosition = inputStream.read(readBuff)
                    if (writeToBuffPosition == 0) {
                        if (builder.size == 0) {
                            return Option<String>.None
                        } else {
                            return builder.toString()
                        }
                    }
                    continue
            }
        }
        throw Exception("unreachable")
    }

    /**
    * Read byte from input stream, return None if eof
    */
    public func readByte(): ?Byte {
        while (true) {
            if (readToBuffPosition < writeToBuffPosition) {
                readToBuffPosition++
                return readBuff[readToBuffPosition - 1]
            } else if (readToBuffPosition == writeToBuffPosition) {
                readToBuffPosition = 0
                writeToBuffPosition = inputStream.read(readBuff)
                if (writeToBuffPosition == 0) {
                    return Option<Byte>.None
                }
            } else {
                throw Exception("readToBuffPosition > writeToBuffPosition")
            }
        }
        throw Exception("unreachable")
    }

    /**
    * Read size of bytes from input stream
    */
    public func readSize(size: Int): Array<Byte> {
        if (size == 0) {
            return Array<Byte>(0, {_=>0})
        }
        let array = Array<Byte>(size, {_=>0})
        for (i in 0..size) {
            array[i] = this.readByte().getOrThrow({=>FtpConnectionException("eof")})
        }
        array
    }

    /**
    * Read until predicate is true
    */
    public func readUntil(predicate: (Rune)->Bool) : ?String {
        let str = StringBuilder();
        while(true) {
            match (readRune()) {
                case Some(rune) =>
                    str.append(rune)
                    if (predicate(rune)) {
                        break
                    }
                case None =>
                    break
            }
        }
        if (str.size == 0) {
            return None
        } 
        str.toString()
    }

    /**
    * Read until rune is found or end of stream, return None if eof
    */
    public func readRune(): ?Rune {
        let builder = ArrayList<Byte>()
        let readByte = match (this.readByte()) {
            case Some(b) => b
            case None => return None
        }
        builder.append(readByte)
        //  # 0xxxxxxx  # 110xxxxx  # 1110xxxx # 11110xxx
        if ((readByte & 0b10000000) == 0) {
            //
        } else if ((readByte & 0b11100000) == 0b11000000) {
            builder.append(this.readByte().getOrThrow({=>FtpConnectionException("eof")}))
        } else if ((readByte & 0b11110000) == 0b11100000) {
            builder.append(this.readByte().getOrThrow({=>FtpConnectionException("eof")}))
            builder.append(this.readByte().getOrThrow({=>FtpConnectionException("eof")}))
        } else if ((readByte & 0b11111000) == 0b11110000) {
            builder.append(this.readByte().getOrThrow({=>FtpConnectionException("eof")}))
            builder.append(this.readByte().getOrThrow({=>FtpConnectionException("eof")}))
            builder.append(this.readByte().getOrThrow({=>FtpConnectionException("eof")}))
        } else {
            throw FtpConnectionException("invalid utf8")
        }
        let ra = String.fromUtf8(builder.toArray()).toRuneArray()
        if (ra.size > 1) {
            throw FtpConnectionException("invalid utf8")
        }
        ra[0]
    }

}

/**
* Write to output stream
*/
public class FtpStreamWriter <: OutputStream {

    private var outputStream: OutputStream

    public init(socket: OutputStream) {
        this.outputStream = socket
    }
    
    public func write(buffer: Array<UInt8>) : Unit {
        outputStream.write(buffer)
    }

    public func write(content: String) {
        outputStream.write(content.toArray())
    }

    public func flush() {
        outputStream.flush()
    }

}

/**
* Connect to host and port
*/
public func defaultConnect(host: String, port: UInt16): StreamingSocket {
    let socket = TcpSocket(host, port)
    socket.writeTimeout = Duration.second * 30
    socket.readTimeout = Duration.second * 30
    socket.connect()
    socket
}

/**
* Create tls connection with socket and handshake
*/
public func tlsConnect(socket: StreamingSocket, session: Option<TlsSession>): StreamingSocket {
    var config = TlsClientConfig()
    config.verifyMode = TrustAll
    let tlsSocket = TlsSocket.client(socket, clientConfig: config, session: session)
    tlsSocket.handshake()
    tlsSocket
}

/**
* Create tls connection with socket and handshake
*/
public func tlsConnect(socket: StreamingSocket): StreamingSocket {
    tlsConnect(socket, None)
}

/**
* Create FtpConnection with socket
*/
public func ftpConnection(socket: StreamingSocket) {
    FtpConnection(socket)
}
