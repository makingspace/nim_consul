import httpclient, asyncdispatch, options, json
from strutils import startsWith, endsWith
import consul/[kv]

export kv.isSome

type
  ConsulBase* = ref object of RootObj
    uri*: string
  AsyncConsul* = ref object of ConsulBase
    client*: AsyncHttpClient
  Consul* = ref object of ConsulBase
    client*: HttpClient

proc initConsulParams*(uri: string = nil): tuple[uri: string] =
  var consulUri = uri
  if consulUri.isNil:
    consulUri = "http://localhost:8500/"

  result = (uri: consulUri)

proc newConsul*(uri: string = nil): Consul =
  let consulUri = initConsulParams(uri)[0]
  result = Consul(uri: consulUri)
  result.client = newHttpClient()

proc newAsyncConsul*(uri: string = nil): AsyncConsul =
  let consulUri = initConsulParams(uri)[0]
  result = AsyncConsul(uri: consulUri)
  result.client = newAsyncHttpClient()

proc path(consul: ConsulBase, path: string): string =
  var separator = if path.startsWith("/") or consul.uri.endsWith("/"): "" else: "/"
  consul.uri & separator & path

proc kvGet*(consul: AsyncConsul | Consul, key: string, aclToken: string = nil): Future[KvResponse] {.multisync.} =

  let
    params = initKvParams(aclToken)
    path = consul.path(kvPath(key, params))
    resp = await consul.client.get(path)
    (consulIndex, errorResponse) = handleErrors(resp)

  if errorResponse.isSome:
    result = (consulIndex, errorResponse.get())
  else:
    # The Consul KV API returns a list of values. For now we will maintain
    # that structure, but only deal with single values.
    let body = await resp.body()
    let json = body.parseJson()[0]
    let item = initKvItem(json)
    result = (consulIndex, @[item])

when isMainModule:
  var consul = newAsyncConsul("http://192.168.111.222:8500")
  let (index, info) = waitFor consul.kvGet("virgil/double_overtime_coefficient")
  echo index
  echo info[0].value

  var consul2 = newConsul("http://192.168.111.222:8500")
  let (index2, info2) = consul2.kvGet("virgil/double_overtime_coefficient")
  echo index2
  echo info2[0].value
