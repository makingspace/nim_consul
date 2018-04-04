import json, options, httpclient, asyncdispatch, strutils
from base64 import decode

type
  KvResponse* = (int, seq[KvItem])
  KvErrorResponse = (int, Option[seq[KvItem]])
  KvItem* = object
    createIndex*, modifyIndex*, lockIndex*, flags*: int
    key*, value*, session*: string
  ConsulException* = object of Exception
  KvNotFound* = object of ConsulException

proc kvPath*(key: string, params: varargs[(string, string)]): string =
  result = "v1/kv/" & key
  if params.len > 0:
    result &= "?"
  for i in params.low..params.high:
    let (k, v) = params[i]
    result &= k & "=" & v
    if i < params.high:
      result &= "&"

proc initKvParams*(aclToken: string = nil): seq[(string, string)] =
  result = newSeq[(string, string)]()
  if not aclToken.isNil:
    result.add(("token", aclToken))

proc isSome*(item: KvItem): bool =
  result = not item.key.isNil

proc initKvItem*(json: JsonNode): KvItem =
  result.createIndex = json["CreateIndex"].getInt
  result.modifyIndex = json["ModifyIndex"].getInt
  result.lockIndex = json["LockIndex"].getInt
  result.flags = json["Flags"].getInt
  result.key = json["Key"].getStr
  result.value = json["Value"].getStr.decode()

proc handleErrors*(resp: Response | AsyncResponse): KvErrorResponse =
  let consulIndex = resp.headers["x-consul-index"].parseInt()

  case resp.code
  of Http404:
    (consulIndex, some(@[KvItem()]))
  else:
    (consulIndex, none seq[KvItem])
