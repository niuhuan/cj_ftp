package cj_ftp.ftp

import cj_ftp.exception.*

/**
* File item in an FTP directory
*/
public class FtpMlsdItem <: ToString {

    public var itemType: String
    public var size: Int64
    public var modify: Float64
    public var unixUid: Int64
    public var unixGid: Int64
    public var unique: String
    public var perms: String
    public var name: String

    public init() {
        this.itemType = ""
        this.size = 0
        this.modify = .0
        this.unixUid = 0
        this.unixGid = 0
        this.unique = ""
        this.perms = ""
        this.name = ""
    }

    public func toString(): String {
        "FtpMlsdItem(type=${itemType}, size=${size}, modify=${modify}, unixUid=${unixUid}, unixGid=${unixGid}, unique=${unique}, perms=${perms}, name=${name})"
    }

}

public class FtpListItem <: ToString {
    public var perms: String
    public var nlink: Int64
    public var user: String
    public var group: String
    public var size: Int64
    public var month: String
    public var day: String
    public var time: String
    public var name: String

    public init() {
        this.perms = ""
        this.nlink = 0
        this.user = ""
        this.group = ""
        this.size = 0
        this.month = ""
        this.day = ""
        this.time = ""
        this.name = ""
    }

    public func toString(): String {
        "FtpListItem(perms=${perms}, nlink=${nlink}, user=${user}, group=${group}, size=${size}, month=${month}, day=${day}, time=${time}, name=${name})"
    }
}

/**
* Response from an FTP server
*/
public class FtpResponse <: ToString {
   public var code: Int64
   public var message: String

   public init() {
      this.code = 0
      this.message = ""
   }

   public init(code: Int64, message: String) {
      this.code = code
      this.message = message
   }

   public func toString(): String {
      "FtpResponse(code=${code}, message=${message})"
   }
}

/**
* Code >= 400 response from an FTP server
*/
public class FtpCommandException <: FtpException & ToString {
    public let response: FtpResponse

    public init(response: FtpResponse) {
        super()
        this.response = response
    }

    public func toString(): String {
        "FtpCommandException(${response.code}, ${response.message})"
    }
}
