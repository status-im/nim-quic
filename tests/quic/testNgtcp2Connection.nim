import std/unittest
import pkg/chronos
import pkg/quic/udp/datagram
import pkg/quic/transport/connectionid
import pkg/quic/transport/ngtcp2
import ../helpers/asynctest
import ../helpers/simulation
import ../helpers/addresses

suite "ngtcp2 connection":

  asynctest "sends outgoing datagrams":
    let client = newNgtcp2Client(zeroAddress, zeroAddress)
    defer: client.destroy()
    client.send()
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  asynctest "processes received datagrams":
    let client = newNgtcp2Client(zeroAddress, zeroAddress)
    defer: client.destroy()

    client.send()
    let datagram = await client.outgoing.get()

    let server = newNgtcp2Server(zeroAddress, zeroAddress, datagram.data)
    defer: server.destroy()

    server.receive(datagram)

  test "raises error when datagram that starts server connection is invalid":
    let invalid = @[0'u8]

    expect IOError:
      discard newNgtcp2Server(zeroAddress, zeroAddress, invalid)

  asynctest "performs handshake":
    let (client, server) = await performHandshake()
    defer: client.destroy
    defer: server.destroy

    check client.isHandshakeCompleted
    check server.isHandshakeCompleted

  asynctest "performs handshake multiple times":
    for i in 1..100:
      let (client, server) = await performHandshake()
      client.destroy()
      server.destroy()

  asynctest "returns the current connection ids":
    let (client, server) = await setupConnection()
    check server.ids.len > 0
    check client.ids.len > 0
    check server.ids != client.ids

  asynctest "notifies about id changes":
    let (client, server) = await setupConnection()
    defer: client.destroy
    defer: server.destroy

    var newId: ConnectionId
    server.onNewId = proc (id: ConnectionId) =
      newId = id

    let simulation = simulateNetwork(client, server)
    defer: await simulation.cancelAndWait()

    await server.handshake.wait()
    check newId != ConnectionId.default
