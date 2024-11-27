package cj_ftp.ftp

import cj_ftp.log.*

import std.os.*
import std.io.*
import std.fs.*

public interface FtpRetr {
    
    func onRetrStart(): Unit

    func onRetrEnd(): Unit

    func onRetrException(e: Exception): Unit

    func onRetrWrite(data: Array<UInt8>): Unit

}

public interface FtpStor {
    
    func onStorStart(): Unit

    func onStorEnd(): Unit

    func onStorException(e: Exception): Unit

    func onStorRead(data: Array<UInt8>): Int64

}

public class FtpRetrFile <: FtpRetr {
    
    private var file: File

    public init(path: String, openOption: OpenOption) {
        this.file = File(path, openOption)
    }

    public init(path: String) {
        this(path, OpenOption.CreateOrTruncate(false))
    }

    public func onRetrStart(): Unit {
    }

    public func onRetrEnd(): Unit {
        file.flush()
        file.close()
    }

    public func onRetrException(e: Exception): Unit {
        cjFtpLogger.error("Error onRetrException: ${e}")
        file.close()
    }

    public func onRetrWrite(data: Array<UInt8>): Unit {
        file.write(data)
    }
}

public class FtpStorFile <: FtpStor {
    
    private var file: File

    public init(path: String, openOption: OpenOption) {
        this.file = File(path, openOption)
    }

    public init(path: String) {
        this(path, OpenOption.Open(true, false))
    }

    public func onStorStart(): Unit {
    }

    public func onStorEnd(): Unit {
        file.close()
    }

    public func onStorException(e: Exception): Unit {
        cjFtpLogger.error("Error onStorException: ${e}")

        file.close()
    }

    public func onStorRead(data: Array<UInt8>): Int64 {
        file.read(data)
    }
}
