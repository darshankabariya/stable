# Waku-RLN-Relay Testnet2: Cross-Client

In this tutorial, the aim is to test the interoperability of the 3 available Waku v2 clients namely, Nim, Go, and JS over the Waku network in the spam-protected mode.
Spam protection is done by rate-limiting each message publisher. 
At the time of this tutorial, the messaging rate is set to `1` per Epoch where Epoch duration is set to `10` seconds.
You will find more about the details of spam protection in the chat clients tutorial provided below.
Messaging rate/spam protection is enabled through [Waku-RLN-Relay protocol](https://rfc.vac.dev/spec/17/) that is mounted on the routing hops.
For ease of demonstration, we make use of Nim-chat, Go-chat, and JS-chat applications that are developed on top of their respective Waku v2 clients.

You need to set up a chat application in spam-protected mode and then start messaging with it. 
As for the setup, please follow the tutorials below:
- [Nim-chat](./onchain-rln-relay-chat2.md)
- [Go-chat](https://github.com/status-im/go-waku/blob/master/docs/tutorials/rln.md)
- [JS-chat](https://examples.waku.org/rln-js/)

Once you set up your chat client, it will be connected to the Waku v2 test fleets as its first hop. 
Messages generated by the chat client are set to be published on a specific combination of pubsub and content topic i.e., the default pubsub topic of `/waku/2/default-waku/proto` and the content topic of `/toy-chat/2/luzhou/proto`. 
The test fleets also run Waku-RLN-Relay over the same pubsub topic and content topic.
Test fleets act as routers and enforce the message rate limit.
As such, any spam messages published by a chat client on the said combination of topics will be caught by the Waku v2 test fleet nodes and will not be routed.
You may also run multiple chat instances from the same or different client implementations to better observe the spam protection done by the Waku v2 test fleets.
Note that spam protection does not rely on the presence of the test fleets.
In fact, all the chat clients (except js-chat as it is in progress) are also capable of catching and dropping spam messages if they receive any.
You can test it by connecting two chat clients (running Waku-RLN-Relay) directly to each other and see if they can spot each other's spam activities.

Note: JS-chat will use the [WAKU2-LIGHTPUSH protocol](https://rfc.vac.dev/spec/19/) to push its messages to the Waku v2 test fleets. 
Waku v2 test fleets will act according to the WAKU2-LIGHTPUSH specifications and push that message to the network without any further verification.
That is, they do not enforce spam protection in that specific protocol but rather act merely as a message publisher (this behavior may change in the future though).
As such, you can expect to receive spam messages published by the JS-chat clients from other connecting chat clients i.e., Go-chat and Nim-chat.
However, you will see that such messages will be immediately identified as spam on those clients and a proper message will be displayed on the console.


You can also find a recorded demo of this testnet in the following [video](https://drive.proton.me/urls/EC4G8SY2J8#ie92Wtje1f4O).