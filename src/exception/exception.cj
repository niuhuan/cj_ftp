package cj_ftp.exception

/**
* Base class for all exceptions in the Ftp module
*/
public open class FtpException <: Exception {
    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }
}

/**
* Exception thrown when an FTP connection fails
*/
public class FtpConnectionException <: FtpException {
    public init(message: String) {
        super(message)
    }
}

/**
* Exception thrown when an FTP command fails
*/
public class FtpParseException <: FtpException {
    public var lines: Array<String>
    public init(message: String) {
        super(message)
        lines = []
    }

    public init(message: String, lines: Array<String>) {
        super(message)
        this.lines = lines
    }

    public init(message: String, line: String) {
        super(message)
        this.lines = [line]
    }
}
