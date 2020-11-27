import std/unittest
import std/sequtils
import pkg/chronos
import pkg/quic
import ../helpers/asynctest
import ../helpers/addresses

suite "udp":

  asynctest "sends outgoing datagrams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    defer: client.destroy()
    client.send()
    let datagram = await client.outgoing.get()
    check datagram.len > 0

  asynctest "processes received datagrams":
    let client = newClientConnection(zeroAddress, zeroAddress)
    defer: client.destroy()

    client.send()
    let datagram = await client.outgoing.get()

    let server = newServerConnection(zeroAddress, zeroAddress, datagram.data)
    defer: server.destroy()

    server.receive(datagram)
