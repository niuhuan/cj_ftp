package cj_ftp.exception

public open class FtpException <: Exception {
    public init() {
        super()
    }

    public init(message: String) {
        super(message)
    }
}

public class FtpConnectionException <: FtpException {
    public init(message: String) {
        super(message)
    }
}

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
