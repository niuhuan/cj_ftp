package cj_ftp.ftp

import cj_ftp.log.*
import cj_ftp.exception.*
import cj_ftp.connection.*

import std.convert.*
import std.io.*
import std.net.*
import std.regex.*
import std.collection.*
import cj_ftp.compatible.*

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
    private var initProt = false

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
            match (regexGroups(responseBaseRegex, line)) {
                case Some(r) =>
                    let code = Int64.parse(r[1])
                    let minusOrSp = r[2]
                    let message = r[3]
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
            add(features, line.trimAscii())
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
        if (!initMode) {
            opts("UTF8", "ON")
            mode("S")
            ftpType("I")
            initMode = true
        }
        if (_tls && !initProt) {
            prot("P")
        }
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
        match (regexGroups(regex, rsp.message)) {
            case Some(r) =>
                r[1]
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
        match (regexGroups(regex, rsp.message)) {
            case Some(r) =>
                r[1]
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
        match (regexGroups(regex, rsp.message)) {
            case Some(r) =>
                let ip = "${r[1]}.${r[2]}.${r[3]}.${r[4]}"
                let port = UInt16.parse(r[5]) * 256 + UInt16.parse(r[6])
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
        match (regexGroups(regex, rsp.message)) {
            case Some(r) =>
                UInt16.parse(r[1])
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
    public func list(path: Option<String>): ArrayList<FtpListItem> {
        checkInitMode()
        let port = pasvPort()
        var cmd = "LIST"
        if (path.isSome()) {
            cmd += " ${path.getOrThrow()}"
        }
        writeCommand(cmd)
        let items = ArrayList<FtpListItem>()
        try (socket = pasvConnect(port)) {
            // 150 Accepted data connection
            readCommand()
            let reader = StringReader(socket)
            while(let Some(line) <- reader.readln()) {
                cjFtpLogger.trace("S: PASV: ${line}", ("name", "Ftp"))
                add(items, parseListLine(line))
            }
        }
        // 226-Options: -a -l
        // 226 2 matches total
        readCommand()
        items
    }

    private func parseListLine(line: String): FtpListItem {
        let item = FtpListItem()
        let regex = Regex("\\s+")
        @When[cjc_version < "0.59.6"]
        var matcher = regex.matcher(line)
        @When[cjc_version < "0.59.6"]
        var findAll = matcher.findAll();
        @When[cjc_version < "0.59.6"]
        var allMatch = if (let Some(findAll) <- findAll) {
            findAll
        } else {
            throw FtpParseException("Invalid LIST response", line)
        }
        @When[cjc_version >= "0.59.6"]
        var findAll = regex.findAll(line);
        @When[cjc_version >= "0.59.6"]
        var allMatch = findAll;
        if (allMatch.size < 8) {
            throw FtpParseException("Invalid LIST response", line)
        }
        let perms = line[0..allMatch[0].matchPosition(0).start]
        let nlink = line[allMatch[0].matchPosition(0).end..allMatch[1].matchPosition(0).start]
        let user = line[allMatch[1].matchPosition(0).end..allMatch[2].matchPosition(0).start]
        let group = line[allMatch[2].matchPosition(0).end..allMatch[3].matchPosition(0).start]
        let size = line[allMatch[3].matchPosition(0).end..allMatch[4].matchPosition(0).start]
        let month = line[allMatch[4].matchPosition(0).end..allMatch[5].matchPosition(0).start]
        let day = line[allMatch[5].matchPosition(0).end..allMatch[6].matchPosition(0).start]
        let time = line[allMatch[6].matchPosition(0).end..allMatch[7].matchPosition(0).start]
        let name =  line[allMatch[7].matchPosition(0).end..]
        item.perms = perms
        item.nlink = Int64.parse(nlink)
        item.user = user
        item.group = group
        item.size = Int64.parse(size)
        item.month = month
        item.day = day
        item.time = time
        item.name = name
        item
    }

    /**
    * `LIST` command for current directory
    *
    * @return list of file items
    */
    public func list(): ArrayList<FtpListItem> {
        list(None)
    }

    /**
    * `MLSD` command, list directory
    *
    * @param path directory path
    * @return list of file items
    */
    public func mlsd(path: Option<String>): ArrayList<FtpMlsdItem> {
        checkInitMode()
        let port = pasvPort()
        var cmd = "MLSD"
        if (path.isSome()) {
            cmd += " ${path.getOrThrow()}"
        }
        writeCommand(cmd)
        let items = ArrayList<FtpMlsdItem>()
        try (socket = pasvConnect(port)) {
            // 150 Accepted data connection
            readCommand()
            let reader = StringReader(socket)
            while(let Some(line) <- reader.readln()) {
                cjFtpLogger.trace("S: PASV: ${line}", ("name", "Ftp"))
                add(items, parseMlsdLine(line))
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
    private func parseMlsdLine(line: String): FtpMlsdItem {
        let item = FtpMlsdItem()
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
    public func mlsd(): ArrayList<FtpMlsdItem> {
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

@When[cjc_version >= "0.59.6"]
public func regexGroups(regex: Regex, line: String): Option<ArrayList<String>> {
    let matchs = regex.find(line);
    match(matchs) {
        case Some(r) => 
            let groups = ArrayList<String>()
            for (i in 0..r.groupCount()) {
                add(groups, r.matchString(i))
            }
            return Some(groups)
        case None => 
            return None
    }
}

@When[cjc_version < "0.59.6"]
public func regexGroups(regex: Regex, line: String): Option<ArrayList<String>> {
    let matchs = regex.matches(line);
    match(matchs) {
        case Some(r) => 
            let groups = ArrayList<String>()
            for (i in 0..r.groupNumber()) {
                add(groups, r.matchStr(i))
            }
            return Some(groups)
        case None => 
            return None
        
    }
}
