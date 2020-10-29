import std/unittest
import quic
import ../helpers/connections
import ../helpers/addresses
import ../helpers/contains

suite "streams":

  test "opens uni-directional streams":
    let (client, _) = performHandshake()

    check client.openStream() != client.openStream()

  test "raises error when opening uni-directional stream fails":
    let client = newClientConnection(zeroAddress, zeroAddress)

    expect IOError:
      discard client.openStream()

  test "closes stream":
    let stream = performHandshake().client.openStream()
    stream.close()

  test "writes to stream":
    let stream = performHandshake().client.openStream()
    let message = @[1'u8, 2'u8, 3'u8]
    let datagram = stream.write(message)
    check datagram.data.contains(message)

  test "raises when stream could not be written to":
    let stream = performHandshake().client.openStream()
    stream.close()

    expect IOError:
      discard stream.write(@[1'u8, 2'u8, 3'u8])