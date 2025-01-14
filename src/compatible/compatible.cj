package cj_ftp.compatible
import std.collection.*

@When[cjc_version >= "0.58.3"]
public func add<T> ( list: List<T>, item: T) {
    list.add(item)
}

@When[cjc_version < "0.58.3"]
public func add<T> ( list: ArrayList<T>, item: T) {
    list.append(item)
}

@When[cjc_version >= "0.58.3"]
public func add<T> ( list: List<T>, item: Collection<T>) {
    list.add(all: item)
}

@When[cjc_version < "0.58.3"]
public func add<T> ( list: ArrayList<T>, item: Collection<T>) {
    list.appendAll(item)
}


