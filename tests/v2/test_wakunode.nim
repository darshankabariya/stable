{.used.}

import
  testutils/unittests,
  chronicles, chronos, stew/shims/net as stewNet, stew/byteutils, std/os,
  libp2p/crypto/crypto,
  libp2p/crypto/secp,
  libp2p/multiaddress,
  libp2p/switch,
  libp2p/protocols/pubsub/rpc/messages,
  libp2p/protocols/pubsub/pubsub,
  libp2p/protocols/pubsub/gossipsub,
  libp2p/nameresolving/mockresolver,
  eth/keys,
  ../../waku/v2/protocol/[waku_relay, waku_message],
  ../../waku/v2/protocol/waku_filter,
  ../../waku/v2/node/peer_manager/peer_manager,
  ../../waku/v2/utils/peers,
  ../../waku/v2/node/wakunode2



template sourceDir: string = currentSourcePath.parentDir()
const KEY_PATH = sourceDir / "resources/test_key.pem"
const CERT_PATH = sourceDir / "resources/test_cert.pem"

procSuite "WakuNode":
  let rng = crypto.newRng()
   
  asyncTest "Messages are correctly relayed":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        Port(60000))
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        Port(60002))
      nodeKey3 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node3 = WakuNode.new(nodeKey3, ValidIpAddress.init("0.0.0.0"),
        Port(60003))
      pubSubTopic = "test"
      contentTopic = ContentTopic("/waku/2/default-content/proto")
      payload = "hello world".toBytes()
      message = WakuMessage(payload: payload, contentTopic: contentTopic)

    await node1.start()
    await node1.mountRelay(@[pubSubTopic])

    await node2.start()
    await node2.mountRelay(@[pubSubTopic])

    await node3.start()
    await node3.mountRelay(@[pubSubTopic])

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])
    await node3.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    var completionFut = newFuture[bool]()
    proc relayHandler(topic: string, data: seq[byte]) {.async, gcsafe.} =
      let msg = WakuMessage.init(data)
      if msg.isOk():
        let val = msg.value()
        check:
          topic == pubSubTopic
          val.contentTopic == contentTopic
          val.payload == payload
      completionFut.complete(true)

    node3.subscribe(pubSubTopic, relayHandler)
    await sleepAsync(2000.millis)

    await node1.publish(pubSubTopic, message)
    await sleepAsync(2000.millis)

    check:
      (await completionFut.withTimeout(5.seconds)) == true
    await node1.stop()
    await node2.stop()
    await node3.stop()
  
  asyncTest "Protocol matcher works as expected":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        Port(60000))
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        Port(60002))
      pubSubTopic = "/waku/2/default-waku/proto"
      contentTopic = ContentTopic("/waku/2/default-content/proto")
      payload = "hello world".toBytes()
      message = WakuMessage(payload: payload, contentTopic: contentTopic)

    # Setup node 1 with stable codec "/vac/waku/relay/2.0.0"

    await node1.start()
    await node1.mountRelay(@[pubSubTopic])
    node1.wakuRelay.codec = "/vac/waku/relay/2.0.0"

    # Setup node 2 with beta codec "/vac/waku/relay/2.0.0-beta2"

    await node2.start()
    await node2.mountRelay(@[pubSubTopic])
    node2.wakuRelay.codec = "/vac/waku/relay/2.0.0-beta2"

    check:
      # Check that mounted codecs are actually different
      node1.wakuRelay.codec ==  "/vac/waku/relay/2.0.0"
      node2.wakuRelay.codec == "/vac/waku/relay/2.0.0-beta2"

    # Now verify that protocol matcher returns `true` and relay works

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    var completionFut = newFuture[bool]()
    proc relayHandler(topic: string, data: seq[byte]) {.async, gcsafe.} =
      let msg = WakuMessage.init(data)
      if msg.isOk():
        let val = msg.value()
        check:
          topic == pubSubTopic
          val.contentTopic == contentTopic
          val.payload == payload
      completionFut.complete(true)

    node2.subscribe(pubSubTopic, relayHandler)
    await sleepAsync(2000.millis)

    await node1.publish(pubSubTopic, message)
    await sleepAsync(2000.millis)

    check:
      (await completionFut.withTimeout(5.seconds)) == true
    await node1.stop()
    await node2.stop()

  asyncTest "resolve and connect to dns multiaddrs":
    let resolver = MockResolver.new()

    resolver.ipResponses[("localhost", false)] = @["127.0.0.1"]

    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"), Port(60000), nameResolver = resolver)
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"), Port(60002))

    # Construct DNS multiaddr for node2
    let
      node2PeerId = $(node2.switch.peerInfo.peerId)
      node2Dns4Addr = "/dns4/localhost/tcp/60002/p2p/" & node2PeerId

    await node1.mountRelay()
    await node2.mountRelay()

    await allFutures([node1.start(), node2.start()])

    await node1.connectToNodes(@[node2Dns4Addr])

    check:
      node1.switch.connManager.connCount(node2.switch.peerInfo.peerId) == 1

    await allFutures([node1.stop(), node2.stop()])

  asyncTest "filtering relayed messages  using topic validators":
    ## test scenario:
    ## node1 and node3 set node2 as their relay node
    ## node3 publishes two messages with two different contentTopics but on the same pubsub topic
    ## node1 is also subscribed  to the same pubsub topic
    ## node2 sets a validator for the same pubsub topic
    ## only one of the messages gets delivered to  node1 because the validator only validates one of the content topics

    let
      # publisher node
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"), Port(60000))
      # Relay node
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"), Port(60002))
      # Subscriber
      nodeKey3 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node3 = WakuNode.new(nodeKey3, ValidIpAddress.init("0.0.0.0"), Port(60003))

      pubSubTopic = "test"
      contentTopic1 = ContentTopic("/waku/2/default-content/proto")
      payload = "hello world".toBytes()
      message1 = WakuMessage(payload: payload, contentTopic: contentTopic1)

      payload2 = "you should not see this message!".toBytes()
      contentTopic2 = ContentTopic("2")
      message2 = WakuMessage(payload: payload2, contentTopic: contentTopic2)

    # start all the nodes
    await node1.start()
    await node1.mountRelay(@[pubSubTopic])

    await node2.start()
    await node2.mountRelay(@[pubSubTopic])

    await node3.start()
    await node3.mountRelay(@[pubSubTopic])

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])
    await node3.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    var completionFutValidatorAcc = newFuture[bool]()
    var completionFutValidatorRej = newFuture[bool]()

    proc validator(topic: string, message: messages.Message): Future[ValidationResult] {.async.} =
      ## the validator that only allows messages with contentTopic1 to be relayed
      check:
        topic == pubSubTopic
      let msg = WakuMessage.init(message.data)
      if msg.isOk():
        # only relay messages with contentTopic1
        if msg.value().contentTopic  == contentTopic1:
          result = ValidationResult.Accept
          completionFutValidatorAcc.complete(true)
        else:
          result = ValidationResult.Reject
          completionFutValidatorRej.complete(true)

    # set a topic validator for pubSubTopic
    let pb  = PubSub(node2.wakuRelay)
    pb.addValidator(pubSubTopic, validator)

    var completionFut = newFuture[bool]()
    proc relayHandler(topic: string, data: seq[byte]) {.async, gcsafe.} =
      debug "relayed pubsub topic:", topic
      let msg = WakuMessage.init(data)
      if msg.isOk():
        let val = msg.value()
        check:
          topic == pubSubTopic
          # check that only messages with contentTopic1 is relayed (but not contentTopic2)
          val.contentTopic == contentTopic1
      # relay handler is called
      completionFut.complete(true)


    node3.subscribe(pubSubTopic, relayHandler)
    await sleepAsync(2000.millis)

    await node1.publish(pubSubTopic, message1)
    await sleepAsync(2000.millis)

    # message2 never gets relayed because of the validator
    await node1.publish(pubSubTopic, message2)
    await sleepAsync(2000.millis)

    check:
      (await completionFut.withTimeout(10.seconds)) == true
      # check that validator is called for message1
      (await completionFutValidatorAcc.withTimeout(10.seconds)) == true
      # check that validator is called for message2
      (await completionFutValidatorRej.withTimeout(10.seconds)) == true


    await node1.stop()
    await node2.stop()
    await node3.stop()
  
  asyncTest "Relay protocol is started correctly":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        Port(60000))

    # Relay protocol starts if mounted after node start

    await node1.start()

    await node1.mountRelay()

    check:
      GossipSub(node1.wakuRelay).heartbeatFut.isNil == false

    # Relay protocol starts if mounted before node start

    let
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        Port(60002))

    await node2.mountRelay()

    check:
      # Relay has not yet started as node has not yet started
      GossipSub(node2.wakuRelay).heartbeatFut.isNil

    await node2.start()

    check:
      # Relay started on node start
      GossipSub(node2.wakuRelay).heartbeatFut.isNil == false

    await allFutures([node1.stop(), node2.stop()])

  asyncTest "Maximum connections can be configured":
    let
      maxConnections = 2
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        Port(60010), maxConnections = maxConnections)
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        Port(60012))
      nodeKey3 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node3 = WakuNode.new(nodeKey3, ValidIpAddress.init("0.0.0.0"),
        Port(60013))

    check:
      # Sanity check, to verify config was applied
      node1.switch.connManager.inSema.size == maxConnections

    # Node with connection limit set to 1
    await node1.start()
    await node1.mountRelay()

    # Remote node 1
    await node2.start()
    await node2.mountRelay()

    # Remote node 2
    await node3.start()
    await node3.mountRelay()

    discard await node1.peerManager.dialPeer(node2.switch.peerInfo.toRemotePeerInfo(), WakuRelayCodec)
    await sleepAsync(3.seconds)
    discard await node1.peerManager.dialPeer(node3.switch.peerInfo.toRemotePeerInfo(), WakuRelayCodec)

    check:
      # Verify that only the first connection succeeded
      node1.switch.isConnected(node2.switch.peerInfo.peerId)
      node1.switch.isConnected(node3.switch.peerInfo.peerId) == false

    await allFutures([node1.stop(), node2.stop(), node3.stop()])


  asyncTest "Messages are relayed between two websocket nodes":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60000), wsBindPort = Port(8000), wsEnabled = true)
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60002), wsBindPort = Port(8100), wsEnabled = true)
      pubSubTopic = "test"
      contentTopic = ContentTopic("/waku/2/default-content/proto")
      payload = "hello world".toBytes()
      message = WakuMessage(payload: payload, contentTopic: contentTopic)

    await node1.start()
    await node1.mountRelay(@[pubSubTopic])

    await node2.start()
    await node2.mountRelay(@[pubSubTopic])

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    var completionFut = newFuture[bool]()
    proc relayHandler(topic: string, data: seq[byte]) {.async, gcsafe.} =
      let msg = WakuMessage.init(data)
      if msg.isOk():
        let val = msg.value()
        check:
          topic == pubSubTopic
          val.contentTopic == contentTopic
          val.payload == payload
      completionFut.complete(true)

    node1.subscribe(pubSubTopic, relayHandler)
    await sleepAsync(2000.millis)

    await node2.publish(pubSubTopic, message)
    await sleepAsync(2000.millis)


    check:
      (await completionFut.withTimeout(5.seconds)) == true
    await node1.stop()
    await node2.stop()


  asyncTest "Messages are relayed between nodes with multiple transports (TCP and Websockets)":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60000), wsBindPort = Port(8000), wsEnabled = true)
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60002))
      pubSubTopic = "test"
      contentTopic = ContentTopic("/waku/2/default-content/proto")
      payload = "hello world".toBytes()
      message = WakuMessage(payload: payload, contentTopic: contentTopic)

    await node1.start()
    await node1.mountRelay(@[pubSubTopic])

    await node2.start()
    await node2.mountRelay(@[pubSubTopic])

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    var completionFut = newFuture[bool]()
    proc relayHandler(topic: string, data: seq[byte]) {.async, gcsafe.} =
      let msg = WakuMessage.init(data)
      if msg.isOk():
        let val = msg.value()
        check:
          topic == pubSubTopic
          val.contentTopic == contentTopic
          val.payload == payload
      completionFut.complete(true)

    node1.subscribe(pubSubTopic, relayHandler)
    await sleepAsync(2000.millis)

    await node2.publish(pubSubTopic, message)
    await sleepAsync(2000.millis)


    check:
      (await completionFut.withTimeout(5.seconds)) == true
    await node1.stop()
    await node2.stop()

  asyncTest "Messages relaying fails with non-overlapping transports (TCP or Websockets)":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60000))
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60002), wsBindPort = Port(8100), wsEnabled = true)
      pubSubTopic = "test"
      contentTopic = ContentTopic("/waku/2/default-content/proto")
      payload = "hello world".toBytes()
      message = WakuMessage(payload: payload, contentTopic: contentTopic)

    await node1.start()
    await node1.mountRelay(@[pubSubTopic])

    await node2.start()
    await node2.mountRelay(@[pubSubTopic])

    #delete websocket peer address
    # TODO: a better way to find the index - this is too brittle
    node2.switch.peerInfo.addrs.delete(0)

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    var completionFut = newFuture[bool]()
    proc relayHandler(topic: string, data: seq[byte]) {.async, gcsafe.} =
      let msg = WakuMessage.init(data)
      if msg.isOk():
        let val = msg.value()
        check:
          topic == pubSubTopic
          val.contentTopic == contentTopic
          val.payload == payload
      completionFut.complete(true)

    node1.subscribe(pubSubTopic, relayHandler)
    await sleepAsync(2000.millis)

    await node2.publish(pubSubTopic, message)
    await sleepAsync(2000.millis)


    check:
      (await completionFut.withTimeout(5.seconds)) == false
    await node1.stop()
    await node2.stop()

  asyncTest "Messages are relayed between nodes with multiple transports (TCP and secure Websockets)":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60000), wsBindPort = Port(8000), wssEnabled = true, secureKey = KEY_PATH, secureCert = CERT_PATH)
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60002))
      pubSubTopic = "test"
      contentTopic = ContentTopic("/waku/2/default-content/proto")
      payload = "hello world".toBytes()
      message = WakuMessage(payload: payload, contentTopic: contentTopic)

    await node1.start()
    await node1.mountRelay(@[pubSubTopic])

    await node2.start()
    await node2.mountRelay(@[pubSubTopic])

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    var completionFut = newFuture[bool]()
    proc relayHandler(topic: string, data: seq[byte]) {.async, gcsafe.} =
      let msg = WakuMessage.init(data)
      if msg.isOk():
        let val = msg.value()
        check:
          topic == pubSubTopic
          val.contentTopic == contentTopic
          val.payload == payload
      completionFut.complete(true)

    node1.subscribe(pubSubTopic, relayHandler)
    await sleepAsync(2000.millis)

    await node2.publish(pubSubTopic, message)
    await sleepAsync(2000.millis)


    check:
      (await completionFut.withTimeout(5.seconds)) == true
    await node1.stop()
    await node2.stop()

  asyncTest "Messages fails with wrong key path":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]

    expect IOError:
      # gibberish
      discard WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60000), wsBindPort = Port(8000), wssEnabled = true, secureKey = "../../waku/v2/node/key_dummy.txt")

  asyncTest "Messages are relayed between nodes with multiple transports (websocket and secure Websockets)":
    let
      nodeKey1 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node1 = WakuNode.new(nodeKey1, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60000), wsBindPort = Port(8000), wssEnabled = true, secureKey = KEY_PATH, secureCert = CERT_PATH)
      nodeKey2 = crypto.PrivateKey.random(Secp256k1, rng[])[]
      node2 = WakuNode.new(nodeKey2, ValidIpAddress.init("0.0.0.0"),
        bindPort = Port(60002),wsBindPort = Port(8100), wsEnabled = true )
      pubSubTopic = "test"
      contentTopic = ContentTopic("/waku/2/default-content/proto")
      payload = "hello world".toBytes()
      message = WakuMessage(payload: payload, contentTopic: contentTopic)

    await node1.start()
    await node1.mountRelay(@[pubSubTopic])

    await node2.start()
    await node2.mountRelay(@[pubSubTopic])

    await node1.connectToNodes(@[node2.switch.peerInfo.toRemotePeerInfo()])

    var completionFut = newFuture[bool]()
    proc relayHandler(topic: string, data: seq[byte]) {.async, gcsafe.} =
      let msg = WakuMessage.init(data)
      if msg.isOk():
        let val = msg.value()
        check:
          topic == pubSubTopic
          val.contentTopic == contentTopic
          val.payload == payload
      completionFut.complete(true)

    node1.subscribe(pubSubTopic, relayHandler)
    await sleepAsync(2000.millis)

    await node2.publish(pubSubTopic, message)
    await sleepAsync(2000.millis)


    check:
      (await completionFut.withTimeout(5.seconds)) == true
    await node1.stop()
    await node2.stop()

  asyncTest "Peer info updates with correct announced addresses":
    let
      nodeKey = crypto.PrivateKey.random(Secp256k1, rng[])[]
      bindIp = ValidIpAddress.init("0.0.0.0")
      bindPort = Port(60000)
      extIp = some(ValidIpAddress.init("127.0.0.1"))
      extPort = some(Port(60002))
      node = WakuNode.new(
        nodeKey,
        bindIp, bindPort,
        extIp, extPort)

    let
      bindEndpoint = MultiAddress.init(bindIp, tcpProtocol, bindPort)
      announcedEndpoint = MultiAddress.init(extIp.get(), tcpProtocol, extPort.get())

    check:
      # Check that underlying peer info contains only bindIp before starting
      node.switch.peerInfo.addrs.len == 1
      node.switch.peerInfo.addrs.contains(bindEndpoint)

      node.announcedAddresses.len == 1
      node.announcedAddresses.contains(announcedEndpoint)

    await node.start()

    check:
      # Check that underlying peer info is updated with announced address
      node.started
      node.switch.peerInfo.addrs.len == 1
      node.switch.peerInfo.addrs.contains(announcedEndpoint)

    await node.stop()

  asyncTest "Node can use dns4 in announced addresses":
    let
      nodeKey = crypto.PrivateKey.random(Secp256k1, rng[])[]
      bindIp = ValidIpAddress.init("0.0.0.0")
      bindPort = Port(60000)
      extIp = some(ValidIpAddress.init("127.0.0.1"))
      extPort = some(Port(60002))
      domainName = "example.com"
      expectedDns4Addr = MultiAddress.init("/dns4/" & domainName & "/tcp/" & $(extPort.get())).get()
      node = WakuNode.new(
        nodeKey,
        bindIp, bindPort,
        extIp, extPort,
        dns4DomainName = some(domainName))

    check:
      node.announcedAddresses.len == 1
      node.announcedAddresses.contains(expectedDns4Addr)
