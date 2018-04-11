## nim_consul.kv: KV operations for Consul
import json, options, httpclient, asyncdispatch, strutils
from base64 import decode

type
  KvIndex = int
  KvResponse* = (KvIndex, seq[KvItem]) ## \
  ## KV Responses take the form of a tuple where the first element is the
  ## global index for the Consul KV at the time of access, and the second is a
  ## sequence of KV Items.
  KvErrorResponse = (KvIndex, Option[seq[KvItem]])
  KvItem* = object
    createIndex*, modifyIndex*, lockIndex*, flags*: int
    key*, value*, session*: string ## \
    ## ``key`` will be the key that the item is accessible at, and ``value`` is
    ## the value currently stored in the KV.

proc kvPath(key: string, params: varargs[(string, string)]): string =
  result = "v1/kv/" & key
  if params.len > 0:
    result &= "?"
  for i in params.low..params.high:
    let (k, v) = params[i]
    result &= k & "=" & v
    if i < params.high:
      result &= "&"

proc kvPath*(key, aclToken: string = nil): string =
  ## Given a key to request and any optional request parameters, construct a
  ## URI path pointing to the Consul KV API.
  var params = newSeq[(string, string)]()
  if not aclToken.isNil:
    params.add(("token", aclToken))

  kvPath(key, params)

proc isSome*(item: KvItem): bool =
  ## Return whether a requested key was found in the KV.
  result = not item.key.isNil

proc initKvItem*(body: string): KvItem =
  ## Given an API response body, extract the expected KV API values from it.
  let json = body.parseJson()[0]
  result.createIndex = json["CreateIndex"].getInt
  result.modifyIndex = json["ModifyIndex"].getInt
  result.lockIndex = json["LockIndex"].getInt
  result.flags = json["Flags"].getInt
  result.key = json["Key"].getStr
  result.value = json["Value"].getStr.decode()

proc handleErrors*(resp: Response | AsyncResponse): KvErrorResponse =
  ## Convert HTTP response errors into KvResponse response values.
  let consulIndex = resp.headers["x-consul-index"].parseInt()

  case resp.code
  of Http404:
    (consulIndex, some(@[KvItem()]))
  else:
    (consulIndex, none seq[KvItem])
