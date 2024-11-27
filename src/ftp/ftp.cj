package cj_ftp.ftp

import cj_ftp.log.*
import cj_ftp.exception.*
import cj_ftp.connection.*

import std.socket.*
import std.convert.*
import std.io.*
import std.regex.*
import std.collection.*

private let responseBaseRegex = Regex("^(\\d\\d\\d)([\\- ])([\\S\\s]+)$")
private let defaultFtpPort: UInt16 = 21

public class Ftp <: Resource {

    private let host: String;
    private let connection: FtpConnection
    private var _feature: ArrayList<String> = ArrayList<String>()
    public prop feature: ArrayList<String> {
        get() {
            feat()
        }
    }

    public init(connection: FtpConnection, host: String) {
        this.host = host
        this.connection = connection
        initFtp()
        feat()
        opts("UTF8", "ON")
        mode("S")
        ftpType("I")
    }

    public init(socket: StreamingSocket, host: String) {
        this(ftpConnection(socket), host)
    }

    public init(host: String, port: UInt16) {
        this(defaultConnect(host, port), host)
    }

    public init(host: String) {
        this(host, defaultFtpPort)
    }
    
    public func close() {
        connection.disconnect()
    }

    public func isClosed(): Bool {
        connection.isClosed()
    }

    private func readCommand(): FtpResponse {
        let reader = this.connection.reader
        let serverResponse = FtpResponse()
        while (true) {
            var line = reader.readln().getOrThrow({=>FtpConnectionException("Connect has been eof")})
            cjFtpLogger.trace("S: ${line}")
            match (responseBaseRegex.matches(line)) {
                case Some(r) =>
                    let code = Int64.parse(r.matchStr(1))
                    let minusOrSp = r.matchStr(2)
                    let message = r.matchStr(3)
                    if (serverResponse.code == 0) {
                        serverResponse.code = code
                    } else if (serverResponse.code != code) {
                        throw  FtpParseException("", line)
                    }
                    if (serverResponse.message != "") {
                        serverResponse.message += "\r\n"
                    }
                    serverResponse.message += message
                    if (minusOrSp == " ") {
                        if (serverResponse.code / 100 > 3) {
                            // 250 OK
                            // 334 VXNlcm5hbWU6
                            // 354 Start mail input; end with <CRLF>.<CRLF>
                            throw FtpCommandException(serverResponse)
                        }
                        return serverResponse
                    }
                case None =>
                    if (serverResponse.code == 211) {
                        // 211-Features:
                        //  MDTM
                        //  REST STREAM
                        //  SIZE
                        // 211 End
                        if (serverResponse.message != "") {
                            serverResponse.message += "\r\n"
                        }
                        serverResponse.message += line
                        continue
                    }
                    throw FtpParseException("Invalid response", line)
            }
        }
        // should not reach here
        throw FtpParseException("Invalid response")
    }

    private func writeCommand(command: String) {
        let writer = this.connection.writer
        cjFtpLogger.trace("C: ${command}")
        writer.write(command)
        writer.write("\r\n")
        writer.flush()
    }

    private func initFtp() {
        readCommand()
    }

    public func feat(): ArrayList<String> {
        writeCommand("FEAT")
        let rsp = readCommand()
        let features = ArrayList<String>()
        for (line in rsp.message.split("\r\n")) {
            if (line.startsWith("211")) {
                continue
            }
            features.append(line.trimAscii())
        }
        this._feature = features
        features
    }

    public func opts(option: String, value: String) {
        writeCommand("OPTS ${option} ${value}")
        readCommand()
    }

    public func mode(mode: String) {
        writeCommand("MODE ${mode}")
        readCommand()
    }

    public func ftpType(ftpType: String) {
        writeCommand("TYPE ${ftpType}")
        readCommand()
    }

    public func auth(authType: String) {
        writeCommand("AUTH ${authType}")
        readCommand()
    }

    public func user(user: String): FtpResponse {
        writeCommand("USER ${user}")
        readCommand()
    }

    public func pass(pass: String): FtpResponse {
        writeCommand("PASS ${pass}")
        readCommand()
    }

    public func login(username: String, password: String) {
        var rsp = user(username)
        if (rsp.code != 331) {
            throw FtpCommandException(rsp)
        }
        this.pass(password)
    }

    public func pwd(): String {
        writeCommand("PWD")
        let rsp = readCommand()
        let regex = Regex("\"([^\"]+)\"")
        match (regex.matcher(rsp.message).find()) {
            case Some(r) =>
                r.matchStr(1)
            case None =>
                throw FtpParseException("Invalid PWD response", rsp.message)
        }
    }

    public func xpwd() {
        writeCommand("XPWD")
        let rsp = readCommand()
        let regex = Regex("\"([^\"]+)\"")
        match (regex.matcher(rsp.message).find()) {
            case Some(r) =>
                r.matchStr(1)
            case None =>
                throw FtpParseException("Invalid PWD response", rsp.message)
        }
    }

    public func cwd(path: String) {
        writeCommand("CWD ${path}")
        readCommand()
    }

    private func pasv(): (String, UInt16) {
        writeCommand("PASV")
        let rsp = readCommand()
        let regex = Regex("(\\d+),(\\d+),(\\d+),(\\d+),(\\d+),(\\d+)")
        match (regex.matcher(rsp.message).find()) {
            case Some(r) =>
                let ip = "${r.matchStr(1)}.${r.matchStr(2)}.${r.matchStr(3)}.${r.matchStr(4)}"
                let port = UInt16.parse(r.matchStr(5)) * 256 + UInt16.parse(r.matchStr(6))
                (ip, port)
            case None =>
                throw FtpParseException("Invalid PASV response", rsp.message)
        }
    }

    private func epsv(): UInt16 {
        writeCommand("EPSV")
        let rsp = readCommand()
        let regex = Regex("\\|\\|\\|(\\d+)\\|")
        match (regex.matcher(rsp.message).find()) {
            case Some(r) =>
                UInt16.parse(r.matchStr(1))
            case None =>
                throw FtpParseException("Invalid EPSV response", rsp.message)
        }
    }

    private func pasvPort(): UInt16 {
        if (this._feature.contains("EPSV")) {
            return epsv()
        }
        if (this._feature.contains("PASV")) {
            let (_, port) = pasv()
            return port
        }
        throw FtpException("No PASV or EPSV feature")
    }

    private func pasvConnect(port: UInt16): StreamingSocket {
        defaultConnect(host, port)
    }

    public func mlsd(path: Option<String>): ArrayList<FtpFileItem> {
        let port = pasvPort()
        var cmd = "MLSD"
        if (path.isSome()) {
            cmd += " ${path.getOrThrow()}"
        }
        writeCommand(cmd)
        let items = ArrayList<FtpFileItem>()
        try (socket = pasvConnect(port)) {
            // 150 Accepted data connection
            readCommand()
            let reader = StringReader(socket)
            while(let Some(line) <- reader.readln()) {
                cjFtpLogger.trace("S: PASV: ${line}")
                items.append(parseMlsdLine(line))
            }
        }
        // 226-Options: -a -l
        // 226 2 matches total
        readCommand()
        items
    }

    private func parseMlsdLine(line: String): FtpFileItem {
        let item = FtpFileItem()
        let parts = line.split(";")
        for (part in parts) {
            let kv = part.split("=")
            if (kv.size != 2) {
                if (item.name == "") {
                    item.name = part.trimAscii()
                }
                continue
            }
            let key = kv[0]
            let value = kv[1]
            match (key.toAsciiLower()) {
                case "type" =>
                    item.itemType = value
                case "size" =>
                    item.size = Int64.parse(value)
                case "modify" =>
                    item.modify = Int64.parse(value)
                case "unix.uid" =>
                    item.unixUid = Int64.parse(value)
                case "unix.gid" =>
                    item.unixGid = Int64.parse(value)
                case "unique" =>
                    item.unique = value
                case "name" =>
                    item.name = value
                case _ =>
                    ()
            }
        }
        item
    }

    public func mlsd() {
        mlsd(None)
    }

    public func retr(path: String, retr: FtpRetr) {
        let port = pasvPort()
        writeCommand("RETR ${path}")
        try (socket = pasvConnect(port)) {
            // 150 Accepted data connection
            readCommand()
            let buffer = Array<UInt8>(4096, {_=>0})
            retr.onRetrStart()
            while (true) {
                let len = socket.read(buffer)
                if (len == 0) {
                    break
                }
                retr.onRetrWrite(buffer.slice(0, len))
            }
            retr.onRetrEnd()
        } catch(e: Exception) {
            retr.onRetrException(e)
        } finally {
            // 226-File successfully transferred
            // 226 0.000 seconds (measured here), 0.00 Mbytes per second
            readCommand()
        }
    }

    public func stor(path: String, stor: FtpStor) {
        let port = pasvPort()
        writeCommand("STOR ${path}")
        try (socket = pasvConnect(port)) {
            // 150 Accepted data connection
            readCommand()
            let buffer = Array<UInt8>(4096, {_=>0})
            stor.onStorStart()
            var all = 0
            var jll = 0
            while (true) {
                let len = stor.onStorRead(buffer)
                all += len
                if (len == 0) {
                    socket.flush()
                    break
                }
                jll += buffer[..len].size
                socket.write(buffer[..len])
            }
            println("all: ${all}, jll: ${jll}")
            stor.onStorEnd()
        } catch(e: Exception) {
            stor.onStorException(e)
        } finally {
            // 226-File successfully transferred
            // 226 0.000 seconds (measured here), 0.00 Mbytes per second
            readCommand()
        }
    }

    public func mkd(path: String) {
        writeCommand("MKD ${path}")
        readCommand()
    }

    public func rmd(path: String) {
        writeCommand("RMD ${path}")
        readCommand()
    }

    public func dele(path: String) {
        writeCommand("DELE ${path}")
        readCommand()
    }

    public func rnfr(path: String) {
        writeCommand("RNFR ${path}")
        readCommand()
    }

    public func rnto(path: String) {
        writeCommand("RNTO ${path}")
        readCommand()
    }

    public func move(from: String, to: String) {
        rnfr(from)
        rnto(to)
    }

    public func noop() {
        writeCommand("NOOP")
        readCommand()
    }

    public func syst() {
        writeCommand("SYST")
        readCommand()
    }

    public func quit() {
        writeCommand("QUIT")
        // 221-Goodbye. You uploaded 0 and downloaded 2 kbytes.
        // 221 Logout.
        readCommand()
    }
}
