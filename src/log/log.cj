package cj_ftp.log

import log.*

protected var cjFtpLogger = getGlobalLogger(("name", "cj_mail"))

public func setCjFtpLogger(logger: Logger): Unit {
    cjFtpLogger = logger
}
