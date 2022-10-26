import
  std/[strutils, nre],
  stew/results,
  chronicles, 
  chronos,
  confutils, 
  confutils/defs, 
  confutils/std/net,
  confutils/toml/defs as confTomlDefs,
  confutils/toml/std/net as confTomlNet,
  libp2p/crypto/crypto,
  libp2p/crypto/secp,
  nimcrypto/utils

export
  confTomlDefs,
  confTomlNet


type ConfResult*[T] = Result[T, string]
   
type
  WakuNodeConf* = object
    ## General node config

    configFile* {.
      desc: "Loads configuration from a TOML file (cmd-line parameters take precedence)"
      name: "config-file" }: Option[InputFile]

    logLevel* {.
      desc: "Sets the log level."
      defaultValue: LogLevel.INFO
      name: "log-level" }: LogLevel

    version* {.
      desc: "prints the version"
      defaultValue: false
      name: "version" }: bool
    
    nodekey* {.
      desc: "P2P node private key as 64 char hex string.",
      defaultValue: defaultPrivateKey()
      name: "nodekey" }: PrivateKey

    listenAddress* {.
      defaultValue: defaultListenAddress()
      desc: "Listening address for LibP2P (and Discovery v5, if enabled) traffic."
      name: "listen-address"}: ValidIpAddress

    tcpPort* {.
      desc: "TCP listening port."
      defaultValue: 60000
      name: "tcp-port" }: Port
    
    portsShift* {.
      desc: "Add a shift to all port numbers."
      defaultValue: 0
      name: "ports-shift" }: uint16

    nat* {.
      desc: "Specify method to use for determining public address. " &
            "Must be one of: any, none, upnp, pmp, extip:<IP>."
      defaultValue: "any" }: string

    maxConnections* {.
      desc: "Maximum allowed number of libp2p connections."
      defaultValue: 50
      name: "max-connections" }: uint16
    
    peerPersistence* {.
      desc: "Enable peer persistence.",
      defaultValue: false,
      name: "peer-persistence" }: bool
    
    # TODO: Deprecated. Remove in next release
    persistPeers* {.
      desc: "DEPRECATED: Use '--peer-persistence' instead.",
      defaultValue: false,
      name: "persist-peers" }: bool
    
    # TODO: Deprecated. Remove in next release
    dbPath* {.
      desc: "DEPRECATED: Use '--store-message-db-url' instead",
      defaultValue: "",
      name: "db-path" }: string
    
    # TODO: Deprecated. Remove in next release
    dbVacuum* {.
      desc: "DEPRECATED: Use '--store-message-db-vacuum' instead",
      defaultValue: false,
      name: "db-vacuum" }: bool
    
    # TODO: Deprecated. Remove in next release
    persistMessages* {.
      desc: "DEPRECATED: Use '--store' instead",
      defaultValue: false
      name: "persist-messages" }: bool
    
    ## DNS addrs config
    
    dnsAddrs* {.
      desc: "Enable resolution of `dnsaddr`, `dns4` or `dns6` multiaddrs"
      defaultValue: true
      name: "dns-addrs" }: bool
    
    dnsAddrsNameServers* {.
      desc: "DNS name server IPs to query for DNS multiaddrs resolution. Argument may be repeated."
      defaultValue: @[ValidIpAddress.init("1.1.1.1"), ValidIpAddress.init("1.0.0.1")]
      name: "dns-addrs-name-server" }: seq[ValidIpAddress]
    
    dns4DomainName* {.
      desc: "The domain name resolving to the node's public IPv4 address",
      defaultValue: ""
      name: "dns4-domain-name" }: string

    ## Relay config
    
    relay* {.
      desc: "Enable relay protocol: true|false",
      defaultValue: true
      name: "relay" }: bool
    
    relayPeerExchange* {.
      desc: "Enable gossipsub peer exchange in relay protocol: true|false",
      defaultValue: false
      name: "relay-peer-exchange" }: bool
    
    rlnRelay* {.
      desc: "Enable spam protection through rln-relay: true|false",
      defaultValue: false
      name: "rln-relay" }: bool
    
    rlnRelayCredPath* {.
      desc: "The path for peristing rln-relay credential",
      defaultValue: ""
      name: "rln-relay-cred-path" }: string

    rlnRelayMembershipIndex* {.
      desc: "(experimental) the index of node in the rln-relay group: a value between 0-99 inclusive",
      defaultValue: 0
      name: "rln-relay-membership-index" }: uint

    rlnRelayPubsubTopic* {.
      desc: "the pubsub topic for which rln-relay gets enabled",
      defaultValue: "/waku/2/default-waku/proto"
      name: "rln-relay-pubsub-topic" }: string

    rlnRelayContentTopic* {.
      desc: "the pubsub topic for which rln-relay gets enabled",
      defaultValue: "/toy-chat/2/luzhou/proto"
      name: "rln-relay-content-topic" }: string
    
    rlnRelayDynamic* {.
      desc: "Enable  waku-rln-relay with on-chain dynamic group management: true|false",
      defaultValue: false
      name: "rln-relay-dynamic" }: bool
  
    rlnRelayIdKey* {.
      desc: "Rln relay identity secret key as a Hex string", 
      defaultValue: ""
      name: "rln-relay-id-key" }: string
    
    rlnRelayIdCommitmentKey* {.
      desc: "Rln relay identity commitment key as a Hex string", 
      defaultValue: ""
      name: "rln-relay-id-commitment-key" }: string
  
    # NOTE: This can be derived from the private key, but kept for future use
    rlnRelayEthAccountAddress* {.
      desc: "Account address for the Ethereum testnet Goerli", 
      defaultValue: ""
      name: "rln-relay-eth-account-address" }: string

    rlnRelayEthAccountPrivateKey* {.
      desc: "Account private key for the Ethereum testnet Goerli",
      defaultValue: ""
      name: "rln-relay-eth-account-private-key" }: string
    
    rlnRelayEthClientAddress* {.
      desc: "WebSocket address of an Ethereum testnet client e.g., ws://localhost:8540/",
      defaultValue: "ws://localhost:8540/"
      name: "rln-relay-eth-client-address" }: string
    
    rlnRelayEthContractAddress* {.
      desc: "Address of membership contract on an Ethereum testnet", 
      defaultValue: ""
      name: "rln-relay-eth-contract-address" }: string
    
    staticnodes* {.
      desc: "Peer multiaddr to directly connect with. Argument may be repeated."
      name: "staticnode" }: seq[string]
    
    keepAlive* {.
      desc: "Enable keep-alive for idle connections: true|false",
      defaultValue: false
      name: "keep-alive" }: bool

    topics* {.
      desc: "Default topics to subscribe to (space separated list)."
      defaultValue: "/waku/2/default-waku/proto"
      name: "topics" .}: string

    ## Store and message store config

    store* {.
      desc: "Enable/disable waku store protocol",
      defaultValue: true
      name: "store" }: bool

    storeMessageRetentionPolicy* {.
      desc: "Message store retention policy. Time retention policy: 'time:<seconds>'. Capacity retention policy: 'capacity:<count>'",
      defaultValue: "time:" & $2.days.seconds,
      name: "store-message-retention-policy" }: string

    storeMessageDbUrl* {.
      desc: "The database connection URL for peristent storage.",
      defaultValue: "sqlite://store.sqlite3",
      name: "store-message-db-url" }: string

    storeMessageDbVacuum* {.
      desc: "Enable database vacuuming at start. Only supported by SQLite database engine.",
      defaultValue: false,
      name: "store-message-db-vacuum" }: bool

    storeMessageDbMigration* {.
      desc: "Enable database migration at start.",
      defaultValue: true,
      name: "store-message-db-migration" }: bool

    storeResumePeer* {.
      desc: "Peer multiaddress to resume the message store at boot.",
      defaultValue: "",
      name: "store-resume-peer" }: string

    # TODO: Deprecated. Remove in next release
    storenode* {.
      desc: "DEPRECATED: Use '--store-resume-peer' instead.",
      defaultValue: ""
      name: "storenode" }: string
    
    # TODO: Deprecated. Remove in next release
    storeCapacity* {.
      desc: "DEPRECATED: Use '--store-message-retention-policy=capacity:<count>' instead",
      defaultValue: 50000
      name: "store-capacity" }: int
    
    # TODO: Deprecated. Remove in next release
    sqliteStore* {.
      desc: "DEPRECATED: SQLite is the default message store implementation.",
      defaultValue: false
      name: "sqlite-store" }: bool

    # TODO: Deprecated. Remove in next release
    sqliteRetentionTime* {.
      desc: "DEPRECATED: Use '--store-message-retention-policy=time:<seconds>' instead",
      defaultValue: 30.days.seconds
      name: "sqlite-retention-time" }: int64
    
    ## Filter config

    filter* {.
      desc: "Enable filter protocol: true|false",
      defaultValue: false
      name: "filter" }: bool
    
    filternode* {.
      desc: "Peer multiaddr to request content filtering of messages.",
      defaultValue: ""
      name: "filternode" }: string
    
    filterTimeout* {.
      desc: "Timeout for filter node in seconds.",
      defaultValue: 14400 # 4 hours
      name: "filter-timeout" }: int64
    
    ## Swap config

    swap* {.
      desc: "Enable swap protocol: true|false",
      defaultValue: false
      name: "swap" }: bool
    
    ## Lightpush config

    lightpush* {.
      desc: "Enable lightpush protocol: true|false",
      defaultValue: false
      name: "lightpush" }: bool
    
    lightpushnode* {.
      desc: "Peer multiaddr to request lightpush of published messages.",
      defaultValue: ""
      name: "lightpushnode" }: string
    
    ## JSON-RPC config

    rpc* {.
      desc: "Enable Waku JSON-RPC server: true|false",
      defaultValue: true
      name: "rpc" }: bool

    rpcAddress* {.
      desc: "Listening address of the JSON-RPC server.",
      defaultValue: ValidIpAddress.init("127.0.0.1")
      name: "rpc-address" }: ValidIpAddress

    rpcPort* {.
      desc: "Listening port of the JSON-RPC server.",
      defaultValue: 8545
      name: "rpc-port" }: uint16
    
    rpcAdmin* {.
      desc: "Enable access to JSON-RPC Admin API: true|false",
      defaultValue: false
      name: "rpc-admin" }: bool
    
    rpcPrivate* {.
      desc: "Enable access to JSON-RPC Private API: true|false",
      defaultValue: false
      name: "rpc-private" }: bool

    ## REST HTTP config

    rest* {.
      desc: "Enable Waku REST HTTP server: true|false",
      defaultValue: false
      name: "rest" }: bool

    restAddress* {.
      desc: "Listening address of the REST HTTP server.",
      defaultValue: ValidIpAddress.init("127.0.0.1")
      name: "rest-address" }: ValidIpAddress

    restPort* {.
      desc: "Listening port of the REST HTTP server.",
      defaultValue: 8645
      name: "rest-port" }: uint16

    restRelayCacheCapacity* {.
      desc: "Capacity of the Relay REST API message cache.",
      defaultValue: 30
      name: "rest-relay-cache-capacity" }: uint32

    restAdmin* {.
      desc: "Enable access to REST HTTP Admin API: true|false",
      defaultValue: false
      name: "rest-admin" }: bool
    
    restPrivate* {.
      desc: "Enable access to REST HTTP Private API: true|false",
      defaultValue: false
      name: "rest-private" }: bool
    
    ## Metrics config

    metricsServer* {.
      desc: "Enable the metrics server: true|false"
      defaultValue: false
      name: "metrics-server" }: bool

    metricsServerAddress* {.
      desc: "Listening address of the metrics server."
      defaultValue: ValidIpAddress.init("127.0.0.1")
      name: "metrics-server-address" }: ValidIpAddress

    metricsServerPort* {.
      desc: "Listening HTTP port of the metrics server."
      defaultValue: 8008
      name: "metrics-server-port" }: uint16

    metricsLogging* {.
      desc: "Enable metrics logging: true|false"
      defaultValue: true
      name: "metrics-logging" }: bool
    
    ## DNS discovery config
    
    dnsDiscovery* {.
      desc: "Enable discovering nodes via DNS"
      defaultValue: false
      name: "dns-discovery" }: bool
    
    dnsDiscoveryUrl* {.
      desc: "URL for DNS node list in format 'enrtree://<key>@<fqdn>'",
      defaultValue: ""
      name: "dns-discovery-url" }: string
    
    dnsDiscoveryNameServers* {.
      desc: "DNS name server IPs to query. Argument may be repeated."
      defaultValue: @[ValidIpAddress.init("1.1.1.1"), ValidIpAddress.init("1.0.0.1")]
      name: "dns-discovery-name-server" }: seq[ValidIpAddress]
    
    ## Discovery v5 config
    
    discv5Discovery* {.
      desc: "Enable discovering nodes via Node Discovery v5"
      defaultValue: false
      name: "discv5-discovery" }: bool
    
    discv5UdpPort* {.
      desc: "Listening UDP port for Node Discovery v5."
      defaultValue: 9000
      name: "discv5-udp-port" }: Port
    
    discv5BootstrapNodes* {.
      desc: "Text-encoded ENR for bootstrap node. Used when connecting to the network. Argument may be repeated."
      name: "discv5-bootstrap-node" }: seq[string]
    
    discv5EnrAutoUpdate* {.
      desc: "Discovery can automatically update its ENR with the IP address " &
            "and UDP port as seen by other nodes it communicates with. " &
            "This option allows to enable/disable this functionality"
      defaultValue: false
      name: "discv5-enr-auto-update" .}: bool

    discv5TableIpLimit* {.
      hidden
      desc: "Maximum amount of nodes with the same IP in discv5 routing tables"
      defaultValue: 10
      name: "discv5-table-ip-limit" .}: uint

    discv5BucketIpLimit* {.
      hidden
      desc: "Maximum amount of nodes with the same IP in discv5 routing table buckets"
      defaultValue: 2
      name: "discv5-bucket-ip-limit" .}: uint

    discv5BitsPerHop* {.
      hidden
      desc: "Kademlia's b variable, increase for less hops per lookup"
      defaultValue: 1
      name: "discv5-bits-per-hop" .}: int

    ## waku peer exchange config
    peerExchange* {.
      desc: "Enable waku peer exchange protocol (responder side): true|false",
      defaultValue: false
      name: "peer-exchange" }: bool

    peerExchangeNode* {.
      desc: "Peer multiaddr to send peer exchange requests to. (enables peer exchange protocol requester side)",
      defaultValue: ""
      name: "peer-exchange-node" }: string

    ## websocket config
    websocketSupport* {.
      desc: "Enable websocket:  true|false",
      defaultValue: false
      name: "websocket-support"}: bool

    websocketPort* {.
      desc: "WebSocket listening port."
      defaultValue: 8000
      name: "websocket-port" }: Port
    
    websocketSecureSupport* {.
      desc: "Enable secure websocket:  true|false",
      defaultValue: false
      name: "websocket-secure-support"}: bool
    
    websocketSecureKeyPath* {.
      desc: "Secure websocket key path:   '/path/to/key.txt' ",
      defaultValue: ""
      name: "websocket-secure-key-path"}: string
    
    websocketSecureCertPath* {.
      desc: "Secure websocket Certificate path:   '/path/to/cert.txt' ",
      defaultValue: ""
      name: "websocket-secure-cert-path"}: string

# NOTE: Keys are different in nim-libp2p
proc parseCmdArg*(T: type crypto.PrivateKey, p: TaintedString): T =
  try:
    let key = SkPrivateKey.init(utils.fromHex(p)).tryGet()
    # XXX: Here at the moment
    result = crypto.PrivateKey(scheme: Secp256k1, skkey: key)
  except CatchableError as e:
    raise newException(ConfigurationError, "Invalid private key")

proc completeCmdArg*(T: type crypto.PrivateKey, val: TaintedString): seq[string] =
  return @[]

proc parseCmdArg*(T: type ValidIpAddress, p: TaintedString): T =
  try:
    result = ValidIpAddress.init(p)
  except CatchableError as e:
    raise newException(ConfigurationError, "Invalid IP address")

proc completeCmdArg*(T: type ValidIpAddress, val: TaintedString): seq[string] =
  return @[]

proc parseCmdArg*(T: type Port, p: TaintedString): T =
  try:
    result = Port(parseInt(p))
  except CatchableError as e:
    raise newException(ConfigurationError, "Invalid Port number")

proc completeCmdArg*(T: type Port, val: TaintedString): seq[string] =
  return @[]

proc defaultListenAddress*(): ValidIpAddress =
  # TODO: How should we select between IPv4 and IPv6
  # Maybe there should be a config option for this.
  (static ValidIpAddress.init("0.0.0.0"))

proc defaultPrivateKey*(): PrivateKey =
  crypto.PrivateKey.random(Secp256k1, crypto.newRng()[]).value

proc readValue*(r: var TomlReader, val: var crypto.PrivateKey)
               {.raises: [Defect, IOError, SerializationError].} =
  val = try: parseCmdArg(crypto.PrivateKey, r.readValue(string))
        except CatchableError as err:
          raise newException(SerializationError, err.msg)


## Configuration validation

let DbUrlRegex = re"^[\w\+]+:\/\/[\w\/\\\.\:\@]+$"

proc validateDbUrl*(val: string): ConfResult[string] =
  let val = val.strip()

  if val == "" or val.match(DbUrlRegex).isSome():
    return ok(val)
  else:
    return err("invalid 'db url' option format: " & val)


let StoreMessageRetentionPolicyRegex = re"^\w+:\w$"

proc validateStoreMessageRetentionPolicy*(val: string): ConfResult[string] =
  let val = val.strip()

  if val == "" or val.match(StoreMessageRetentionPolicyRegex).isSome():
    return ok(val)
  else:
    return err("invalid 'store message retention policy' option format: " & val)