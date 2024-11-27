package cj_ftp.connection

import std.collection.*
import std.socket.*
import std.io.*
import std.time.*
import net.tls.*
import cj_ftp.exception.*

public class FtpConnection <: Resource{

    private var socket: StreamingSocket
    public var reader: FtpStreamReader 
    public var writer: StreamWriter

    public init(socket: StreamingSocket) {
        this.socket = socket
        this.reader = FtpStreamReader(socket)
        this.writer = StreamWriter(socket)
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

}


public class FtpStreamReader {
    
    var readBuff = Array<Byte>(8192, {_=>0})
    var writeToBuffPosition = 0
    var readToBuffPosition = 0

    var inputStream: InputStream

    public init(socket: InputStream) {
        this.inputStream = socket
    }

    // public func deflate() {
    //     inputStream = DecompressInputStream(inputStream, wrap: DeflateFormat, bufLen: 1)
    // }

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

public class StreamWriter <: OutputStream{

    var writeBuff = Array<Byte>(8192, {_=>0})
    var writeBuffPosition = 0

    var outputStream: OutputStream

    public init(socket: OutputStream) {
        this.outputStream = socket
    }

    // public func deflate() {
    //     outputStream = CompressOutputStream(outputStream, wrap: DeflateFormat, bufLen: 1)
    // }
    
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

public func defaultConnect(host: String, port: UInt16): StreamingSocket {
    let socket = TcpSocket(host, port)
    socket.writeTimeout = Duration.second * 30
    socket.readTimeout = Duration.second * 30
    socket.connect()
    socket
}

public func ftpConnection(socket: StreamingSocket) {
    FtpConnection(socket)
}
