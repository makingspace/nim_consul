## nim_consul: simple Consul access from Nim
##
## This library provides an SDK around the Consul (https://www.consul.io/) HTTP
## API. Currently it's extremely underdeveloped; it exposes a single element of
## the api, ``kvGet``, which allows for the retrieval of elements from the
## Consul kv store.

import httpclient, asyncdispatch, options
from strutils import startsWith, endsWith, `%`
import consul/[kv]

export kv.isSome

const defaultPort = 8500

type
  ConsulBase = ref object of RootObj
    uri*: string
  Consul* = ref object of ConsulBase ## \
    ## The blocking version of the Consul agent client.
    client: HttpClient
  AsyncConsul* = ref object of ConsulBase ## \
    ## The async version of the Consul agent client.
    client: AsyncHttpClient

proc initConsulParams(uri: string = nil): tuple[uri: string] =
  var consulUri = uri
  if consulUri.isNil:
    consulUri = "http://localhost:$#/" % $defaultPort

  result = (uri: consulUri)

proc newConsul*(uri: string = nil): Consul =
  ## Create a new Consul agent client. Accepts an optional argument ``uri``,
  ## the URI at which to make agent requests. If no uri is provided, defaults
  ## to looking for an agent running on localhost at the default port.
  runnableExamples:
    let consul = newConsul()
    doAssert "http://localhost:8500/" == consul.uri
    let
      customUri = "https://192.168.111.222:8761"
      consul2 = newConsul(customUri)
    doAssert consul2.uri == customUri

  let consulUri = initConsulParams(uri)[0]
  result = Consul(uri: consulUri)
  result.client = newHttpClient()

proc newAsyncConsul*(uri: string = nil): AsyncConsul =
  ## Create a new Consul agent client. Accepts an optional argument ``uri``,
  ## the URI at which to make agent requests. If no uri is provided, defaults
  ## to looking for an agent running on localhost at the default port.
  ##
  ## Uses AsyncHttpClient as the underlying HTTP client, so all API operations
  ## are async.
  runnableExamples:
    let consul = newAsyncConsul()
    doAssert "http://localhost:8500/" == consul.uri
    let
      customUri = "https://192.168.111.222:8761"
      consul2 = newAsyncConsul(customUri)
    doAssert consul2.uri == customUri

  let consulUri = initConsulParams(uri)[0]
  result = AsyncConsul(uri: consulUri)
  result.client = newAsyncHttpClient()

proc path(consul: ConsulBase, path: string): string =
  var separator = if path.startsWith("/") or consul.uri.endsWith("/"): "" else: "/"
  consul.uri & separator & path

proc kvGet*(consul: AsyncConsul | Consul, key: string, aclToken: string = nil): Future[KvResponse] {.multisync.} =
  ## Retrieve a single element from the kv store. Accepts an optional
  ## ``aclToken`` argument if the kv has an ACL in place.
  ##
  ## Currently only returns a single value, regardless of how many are returned by the API.
  runnableExamples:
    let
      consul = newConsul("http://192.168.111.222:8500")
      (idx, kvItems) = consul.kvGet("virgil/nj/staff_per_route")

  let
    path = consul.path(kvPath(key, aclToken))
    resp = await consul.client.get(path)
    (consulIndex, errorResponse) = handleErrors(resp)

  if errorResponse.isSome:
    result = (consulIndex, errorResponse.get())
  else:
    # The Consul KV API returns a list of values. For now we will maintain
    # that structure, but only deal with single values.
    let
      body = await resp.body()
      item = initKvItem(body)
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
