import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic

suite "api":
  setup:
    var listener = listen(initTAddress("127.0.0.1:0"))
    let address = listener.localAddress

  teardown:
    waitFor listener.stop()

  asyncTest "opens and drops connections":
    let dialing = dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    check:
      outgoing.remoteAddress.port == address.port
      outgoing.localAddress.port == incoming.remoteAddress.port
      incoming.localAddress.port == address.port

    await outgoing.drop()
    await incoming.drop()

  asyncTest "opens and closes streams":
    let dialing = dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    let stream1 = await outgoing.openStream()
    let stream2 = await incoming.openStream()

    await stream1.close()
    await stream2.close()

    await outgoing.drop()
    await incoming.drop()

  asyncTest "waits until peer closes connection":
    let dialing = dial(address)
    let accepting = listener.accept()

    let outgoing = await dialing
    let incoming = await accepting

    await incoming.close()
    await outgoing.waitClosed()

  asyncTest "accepts multiple incoming connections":
    let accepting1 = listener.accept()
    let outgoing1 = await dial(address)
    let incoming1 = await accepting1

    let accepting2 = listener.accept()
    let outgoing2 = await dial(address)
    let incoming2 = await accepting2

    check incoming1 != incoming2

    await outgoing1.drop()
    await outgoing2.drop()
    await incoming1.drop()
    await incoming2.drop()

  asyncTest "writes to and reads from streams":
    let message = @[1'u8, 2'u8, 3'u8]

    let outgoing = await dial(address)
    defer: await outgoing.drop()

    let incoming = await listener.accept()
    defer: await incoming.drop()

    let outgoingStream = await outgoing.openStream()
    defer: await outgoingStream.close()

    await outgoingStream.write(message)

    let incomingStream = await incoming.incomingStream()
    defer: await incomingStream.close()

    check (await incomingStream.read()) == message
