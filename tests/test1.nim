import unittest, asyncdispatch, osproc, strutils
import consul

suite "consul tests":

  test "connect sync":
    let consul = newConsul()
    check "http://localhost:8500/" == consul.uri
    expect(OsError):
      discard consul.kvGet("foo")

  test "connect async":
    let consul = newAsyncConsul()
    check "http://localhost:8500/" == consul.uri
    expect(OsError):
      discard waitFor consul.kvGet("foo")

suite "integration tests":

  setUp:
    const
      serverPath = "192.168.111.222"
      consulPath = "http://$#:8500/" % serverPath
    let
      consul = newConsul(consulPath)
      asyncConsul = newAsyncConsul(consulPath)

  test "check for vagrant":
    require execCmd("ping $# -c1 > /dev/null" % serverPath) == 0

  test "kv get sync 404":
    let
      (idx, kvItems) = consul.kvGet("ok")
      item = kvItems[0]
    check(not item.isSome)

  test "kv get async 404":
    let
      (idx, kvItems) = waitFor asyncConsul.kvGet("ok")
      item = kvItems[0]
    check(not item.isSome)

  test "kv get sync 200":
    let
      (idx, kvItems) = consul.kvGet("virgil/nj/staff_per_route")
      item = kvItems[0]
    check item.isSome
    check item.value.parseFloat() > 0.0

  test "kv get async 200":
    let
      (idx, kvItems) = waitFor asyncConsul.kvGet("virgil/nj/staff_per_route")
      item = kvItems[0]
    check item.isSome
    check item.value.parseFloat() > 0.0
