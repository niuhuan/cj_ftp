package cj_ftp.ftp

import cj_ftp.log.*

import std.io.*
import std.fs.*

@When[cjc_version < "0.57.3"]
public type OpenMode = OpenOption

@When[cjc_version < "0.57.3"]
public let modeRead = OpenOption.Open(true, false)

@When[cjc_version < "0.57.3"]
public let modeWrite = OpenOption.CreateOrTruncate(false)

@When[cjc_version >= "0.57.3"]
public let modeRead = OpenMode.Read

@When[cjc_version >= "0.57.3"]
public let modeWrite = OpenMode.Write

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

    public init(path: String, openMode: OpenMode) {
        this.file = File(path, openMode)
    }

    public init(path: String) {
        this(path, modeWrite)
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

    public init(path: String, openMode: OpenMode) {
        this.file = File(path, openMode)
    }

    public init(path: String) {
        this(path, modeRead)
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

public class FtpRetrStream <: FtpRetr {
        
        private var outputStream: OutputStream
    
        public init(outputStream: OutputStream) {
            this.outputStream = outputStream
        }
    
        public func onRetrStart(): Unit {
        }
    
        public func onRetrEnd(): Unit {
            outputStream.flush()
        }
    
        public func onRetrException(e: Exception): Unit {
            cjFtpLogger.error("Error onRetrException: ${e}")
        }
    
        public func onRetrWrite(data: Array<UInt8>): Unit {
            outputStream.write(data)
        }
}

public class FtpStorStream <: FtpStor {
    
    private var inputStream: InputStream

    public init(inputStream: InputStream) {
        this.inputStream = inputStream
    }

    public func onStorStart(): Unit {
    }

    public func onStorEnd(): Unit {
    }

    public func onStorException(e: Exception): Unit {
        cjFtpLogger.error("Error onStorException: ${e}")
    }

    public func onStorRead(data: Array<UInt8>): Int64 {
        inputStream.read(data)
    }
}
