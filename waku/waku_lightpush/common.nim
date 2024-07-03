{.push raises: [].}

import stew/results, chronos, libp2p/peerid
import ../waku_core

const WakuLightPushCodec* = "/vac/waku/lightpush/2.0.0-beta1"

type WakuLightPushResult*[T] = Result[T, string]

type PushMessageHandler* = proc(
  peer: PeerId, pubsubTopic: PubsubTopic, message: WakuMessage
): Future[WakuLightPushResult[void]] {.async.}

const TooManyRequestsMessage* = "TOO_MANY_REQUESTS"
