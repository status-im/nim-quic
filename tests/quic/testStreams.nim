import std/sequtils
import pkg/chronos
import pkg/chronos/unittest2/asynctests
import pkg/quic/errors
import pkg/quic/transport/stream
import pkg/quic/transport/quicconnection
import pkg/quic/transport/ngtcp2/native
import pkg/quic/udp/datagram
import ../helpers/simulation
import ../helpers/contains

suite "streams":
  setup:
    var (client, server) = waitFor performHandshake()

  teardown:
    waitFor client.drop()
    waitFor server.drop()

  asyncTest "opens uni-directional streams":
    let stream1, stream2 = await client.openStream(unidirectional = true)
    check stream1 != stream2
    check stream1.isUnidirectional
    check stream2.isUnidirectional

  asyncTest "opens bi-directional streams":
    let stream1, stream2 = await client.openStream()
    check stream1 != stream2
    check not stream1.isUnidirectional
    check not stream2.isUnidirectional

  asyncTest "closes stream":
    let stream = await client.openStream()
    await stream.close()

  asyncTest "writes to stream":
    let stream = await client.openStream()
    let message = @[1'u8, 2'u8, 3'u8]
    await stream.write(message)

    check client.outgoing.anyIt(it.data.contains(message))

  asyncTest "writes zero-length message":
    let stream = await client.openStream()
    await stream.write(@[])
    let datagram = await client.outgoing.get()

    check datagram.len > 0

  asyncTest "raises when reading from or writing to closed stream":
    let stream = await client.openStream()
    await stream.close()

    expect QuicError:
      discard await stream.read()

    expect QuicError:
      await stream.write(@[1'u8, 2'u8, 3'u8])

  asyncTest "accepts incoming streams":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[])

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    await simulation.cancelAndWait()

  asyncTest "reads from stream":
    let simulation = simulateNetwork(client, server)
    let message = @[1'u8, 2'u8, 3'u8]

    let clientStream = await client.openStream()
    await clientStream.write(message)

    let serverStream = await server.incomingStream()
    check clientStream.id == serverStream.id

    let incoming = await serverStream.read()
    check incoming == message

    await simulation.cancelAndWait()

  asyncTest "writes long messages to stream":
    let simulation = simulateNetwork(client, server)

    let stream = await client.openStream()
    let message = repeat(42'u8, 100 * sizeof(Ngtcp2Connection.buffer))
    asyncSpawn stream.write(message)

    let incoming = await server.incomingStream()
    for _ in 0..<100:
      discard await incoming.read()

    await simulation.cancelAndWait()

  asyncTest "halts sender until receiver has caught up":
    let simulation = simulateNetwork(client, server)
    let message = repeat(42'u8, sizeof(Ngtcp2Connection.buffer))

    # send until blocked
    let sender = await client.openStream()
    while true:
      if not await sender.write(message).withTimeout(100.milliseconds):
        break

    # receive until blocked
    let receiver = await server.incomingStream()
    while true:
      if not await receiver.read().withTimeout(100.milliseconds):
        break

    # check that sender is unblocked
    check await sender.write(message).withTimeout(100.milliseconds)

    await simulation.cancelAndWait()

  asyncTest "handles packet loss":
    let simulation = simulateLossyNetwork(client, server)

    let message = @[1'u8, 2'u8, 3'u8]
    let clientStream = await client.openStream()
    await clientStream.write(message)

    let serverStream = await server.incomingStream()
    let incoming = await serverStream.read()

    check incoming == message

    await simulation.cancelAndWait()

  asyncTest "raises when stream is closed by peer":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[1'u8, 2'u8, 3'u8])

    let serverStream = await server.incomingStream()
    discard await serverStream.read()

    await clientStream.close()
    await sleepAsync(100.milliseconds) # wait for stream to be closed

    expect QuicError:
      discard await serverStream.read()

    expect QuicError:
      await serverStream.write(@[1'u8, 2'u8, 3'u8])

    await simulation.cancelAndWait()

  asyncTest "closes stream when underlying connection is closed by peer":
    let simulation = simulateNetwork(client, server)

    let clientStream = await client.openStream()
    await clientStream.write(@[1'u8, 2'u8, 3'u8])

    let serverStream = await server.incomingStream()
    discard await serverStream.read()

    await client.close()
    await sleepAsync(100.milliseconds) # wait for connection to be closed

    check serverStream.isClosed

    await simulation.cancelAndWait()

  asyncTest "reads last bytes from stream that is closed by peer":
    let simulation = simulateNetwork(client, server)
    let message = @[1'u8, 2'u8, 3'u8]

    let clientStream = await client.openStream()
    await clientStream.write(message)
    await clientStream.close()
    await sleepAsync(100.milliseconds) # wait for stream to be closed

    let serverStream = await server.incomingStream()
    let incoming = await serverStream.read()
    check incoming == message

    await simulation.cancelAndWait()
