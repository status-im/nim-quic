import std/unittest
import chronos
import quic
import ../helpers/asynctest
import ../helpers/connections
import ../helpers/addresses
import ../helpers/contains

suite "streams":

  asynctest "opens uni-directional streams":
    let (client, _) = await performHandshake()

    check client.openStream() != client.openStream()

  test "raises error when opening uni-directional stream fails":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      discard client.openStream()

  asynctest "closes stream":
    let (client, _) = await performHandshake()
    let stream = client.openStream()
    stream.close()

  asynctest "writes to stream":
    let (client, _) = await performHandshake()
    let stream = client.openStream()
    let message = @[1'u8, 2'u8, 3'u8]
    await stream.write(message)
    let datagram = await client.outgoing.get()
    check datagram.data.contains(message)

  asynctest "writes zero-length message":
    let (client, _) = await performHandshake()
    let stream = client.openStream()
    await stream.write(@[])
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  asynctest "raises when stream could not be written to":
    let (client, _) = await performHandshake()
    let stream = client.openStream()
    stream.close()

    expect IOError:
      await stream.write(@[1'u8, 2'u8, 3'u8])