package cj_ftp.ftp

import cj_ftp.log.*
import cj_ftp.exception.*
import cj_ftp.connection.*

import std.socket.*
import std.convert.*
import std.io.*
import std.net.*
import std.regex.*
import std.collection.*

private let responseBaseRegex = Regex("^(\\d\\d\\d)([\\- ])([\\S\\s]+)$")
private let defaultFtpPort: UInt16 = 21

/**
* FTP client / Once ftp connection
*/
public class Ftp <: Resource {

    private let host: String
    private let connection: FtpConnection
    private var _features: ArrayList<String> = ArrayList<String>()
    public prop features: ArrayList<String> {
        get() {
            _features
        }
    }
    private var _tls = false;
    public prop tls: Bool {
        get() {
            this._tls
        }
    }
    private var initMode = false

    public init(connection: FtpConnection, host: String) {
        this.host = host
        this.connection = connection
        serverHello()
        feat()
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
            cjFtpLogger.trace("S: ${line}", ("name", "Ftp"))
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
        cjFtpLogger.trace("C: ${command}", ("name", "Ftp"))
        writer.write(command)
        writer.write("\r\n")
        writer.flush()
    }

    private func serverHello() {
        readCommand()
    }

    /**
    * Get server features
    */
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
        this._features = features
        features
    }

    /**
    * Set options
    */
    public func opts(option: String, value: String): Unit {
        writeCommand("OPTS ${option} ${value}")
        readCommand()
    }

    /**
    * Set mode
    */
    public func mode(mode: String): Unit {
        writeCommand("MODE ${mode}")
        readCommand()
    }

    /**
    * Set type
    */
    public func ftpType(ftpType: String): Unit {
        writeCommand("TYPE ${ftpType}")
        readCommand()
    }

    /**
    * Set auth\n
    * authType: TLS, SSL, TLS-C, SSL-C
    */
    private func auth(authType: String) {
        writeCommand("AUTH ${authType}")
        readCommand()
    }

    /**
    * Set prot level
    */
    public func prot(prot: String) {
        writeCommand("PROT ${prot}")
        readCommand()
    }

    private func checkInitMode() {
        if (initMode) {
            return
        }
        opts("UTF8", "ON")
        mode("S")
        ftpType("I")
        try {
            prot("P")
        } catch (e: Exception) {
            cjFtpLogger.error("Error PROT: ${e}")
        }
        initMode = true
    }

    private func authTls() {
        auth("TLS")
        this._tls = true
        connection.startTls()
    }

    private func authSsl() {
        auth("SSL")
        this._tls = true
        connection.startTls()
    }

    private func tryAuthTls(): Bool {
        if (_features.contains("AUTH TLS")) {
            try {
                authTls()
                return true
            } catch(e: FtpCommandException) {
                cjFtpLogger.error("Error tryAuthTls: ${e}")
                return false
            }
        }
        false
    }

    private func tryAuthSsl(): Bool {
        if (_features.contains("AUTH SSL")) {
            try {
                authSsl()
                return true
            } catch(e: FtpCommandException) {
                cjFtpLogger.error("Error tryAuthSsl: ${e}")
                return false
            }
        }
        false
    }

    /**
    * Try to connect secure
    */
    public func tryIntoSecure(): Bool {
        if (tryAuthTls()) {
            return true
        }
        if (tryAuthSsl()) {
            return true
        }
        return false
    }

    /**
    * `USER` command
    */
    public func user(user: String): FtpResponse {
        writeCommand("USER ${user}")
        readCommand()
    }

    /**
    * `PASS` command
    */
    public func pass(pass: String): FtpResponse {
        writeCommand("PASS ${pass}")
        readCommand()
    }

    /**
    * Login with `USER` and `PASS` command
    */
    public func login(username: String, password: String) {
        var rsp = user(username)
        if (rsp.code != 331) {
            throw FtpCommandException(rsp)
        }
        this.pass(password)
        checkInitMode()
    }

    /**
    * `PWD` command
    *
    * @return current working directory
    */
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

    /**
    * `XPWD` command
    *
    * @return current working directory
    */
    public func xpwd(): String {
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

    /**
    * `CWD` command
    */
    public func cwd(path: String) {
        writeCommand("CWD ${path}")
        readCommand()
    }

    /**
    * `PASV` command
    *
    * @return (ip, port)
    */
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

    /**
    * `EPSV` command
    *
    * @return port
    */
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

    /**
    * Get port for data connection
    *
    * @return port
    */
    private func pasvPort(): UInt16 {
        if (this._features.contains("EPSV")) {
            return epsv()
        }
        if (this._features.contains("PASV")) {
            let (_, port) = pasv()
            return port
        }
        throw FtpException("No PASV or EPSV feature")
    }

    /**
    * Connect to server with PASV
    *
    * @param port port for data connection
    */
    private func pasvConnect(port: UInt16): StreamingSocket {
        let socket = defaultConnect(host, port)
        if (_tls) {
            tlsConnect(socket, connection.tlsSession())
        } else {  
            socket
        }
    }

    /**
    * `MLSD` command, list directory
    *
    * @param path directory path
    * @return list of file items
    */
    public func mlsd(path: Option<String>): ArrayList<FtpFileItem> {
        checkInitMode()
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
                cjFtpLogger.trace("S: PASV: ${line}", ("name", "Ftp"))
                items.append(parseMlsdLine(line))
            }
        }
        // 226-Options: -a -l
        // 226 2 matches total
        readCommand()
        items
    }

    /**
    * Parse MLSD line
    */
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
                    item.modify = Float64.parse(value)
                case "unix.uid" =>
                    item.unixUid = Int64.parse(value)
                case "unix.gid" =>
                    item.unixGid = Int64.parse(value)
                case "unique" =>
                    item.unique = value
                case "perms" =>
                    item.perms = value
                case "name" =>
                    item.name = value
                case _ =>
                    ()
            }
        }
        item
    }

    /**
    * `MLSD` command for current directory
    *
    * @return list of file items
    */
    public func mlsd(): ArrayList<FtpFileItem> {
        mlsd(None)
    }

    /**
    * `RETR` command download file
    *
    * @param path remote file path
    * @param retr callback for download
    */
    public func retr(path: String, retr: FtpRetr): Unit {
        checkInitMode()
        let port = pasvPort()
        writeCommand("RETR ${path}")
        var exception: ?Exception = None
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
            exception = e
            retr.onRetrException(e)
        } finally {
            // 226-File successfully transferred
            // 226 0.000 seconds (measured here), 0.00 Mbytes per second
            readCommand()
            if (let Some(e) <- exception) {
                throw e
            }
        }
    }

    /**
    * `RETR` command download file to stream
    *
    * @param path remote file path
    * @param stream output stream
    */
    public func retr(path: String, stream: OutputStream) {
        retr(path, FtpRetrStream(stream))
    }

    /**
    * `STOR-like` command upload file
    *
    * @param path remote file path
    * @param stor callback for upload
    */
    private func storeCommand(command: String, stor: FtpStor): Unit {
        checkInitMode()
        let port = pasvPort()
        writeCommand(command)
        var exception: ?Exception = None
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
            exception = e
            stor.onStorException(e)
        } finally {
            // 226-File successfully transferred
            // 226 0.000 seconds (measured here), 0.00 Mbytes per second
            readCommand()
            if (let Some(e) <- exception) {
                throw e
            }
        }
    }

    /**
    * `STOR` command upload file
    *
    * @param path remote file path
    * @param stor callback for upload
    */
    public func stor(path: String, stor: FtpStor) {
        storeCommand("STOR ${path}", stor)
    }

    /**
    * `STOR` command upload file from stream
    *
    * @param path remote file path
    * @param stream input stream
    */
    public func stor(path: String, stream: InputStream) {
        stor(path, FtpStorStream(stream))
    }

    /**
    * `APPE` command append file
    *
    * @param path remote file path
    * @param stor callback for upload
    */
    public func appe(path: String, stor: FtpStor) {
        storeCommand("APPE ${path}", stor)
    }

    /**
    * `APPE` command append file from stream
    *
    * @param path remote file path
    * @param stream input stream
    */
    public func appe(path: String, stream: InputStream) {
        appe(path, FtpStorStream(stream))
    }

    /**
    * `STOU` command upload file
    *
    * @param path remote file path
    * @param stor callback for upload
    */
    public func stou(path: String, stor: FtpStor) {
        storeCommand("STOU ${path}", stor)
    }

    /**
    * `STOU` command upload file from stream
    *
    * @param path remote file path
    * @param stream input stream
    */
    public func stou(path: String, stream: InputStream) {
        stou(path, FtpStorStream(stream))
    }

    /**
    * `MKD` command make directory
    *
    * @param path directory path
    */
    public func mkd(path: String) {
        writeCommand("MKD ${path}")
        readCommand()
    }

    /**
    * `RMD` command remove directory
    *
    * @param path directory path
    */
    public func rmd(path: String) {
        writeCommand("RMD ${path}")
        readCommand()
    }

    /**
    * `DELE` command delete file
    *
    * @param path file path
    */
    public func dele(path: String) {
        writeCommand("DELE ${path}")
        readCommand()
    }

    /**
    * `RNFR` command rename from
    *
    * @param path file path
    */
    public func rnfr(path: String) {
        writeCommand("RNFR ${path}")
        readCommand()
    }

    /**
    * `RNTO` command rename to
    *
    * @param path file path
    */
    public func rnto(path: String) {
        writeCommand("RNTO ${path}")
        readCommand()
    }
    
    /**
    * `RNFR` and `RNTO` command rename
    *
    * @param from file path
    * @param to file path
    */
    public func move(from: String, to: String) {
        rnfr(from)
        rnto(to)
    }

    /**
    * `NOOP` command
    */
    public func noop() {
        writeCommand("NOOP")
        readCommand()
    }

    /**
    * `SYST` command
    */
    public func syst() {
        writeCommand("SYST")
        readCommand()
    }

    /**
    * `QUIT` command
    */
    public func quit() {
        writeCommand("QUIT")
        // 221-Goodbye. You uploaded 0 and downloaded 2 kbytes.
        // 221 Logout.
        readCommand()
    }
}
