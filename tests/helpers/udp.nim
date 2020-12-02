import pkg/chronos
import pkg/quic/packets
import pkg/quic/version
import pkg/quic/openarray

proc exampleQuicDatagram*: seq[byte] =
  var packet = initialPacket(CurrentQuicVersion)
  packet.destination = randomConnectionId()
  packet.source = randomConnectionId()
  result = newSeq[byte](4096)
  result.write(packet)

proc sendTo*(datagram: seq[byte], remote: TransportAddress) {.async.} =
  proc onReceive(udp: DatagramTransport, remote: TransportAddress) {.async.} =
    discard
  let udp = newDatagramTransport(onReceive)
  await udp.sendTo(remote, datagram.toUnsafePtr, datagram.len)
  await udp.closeWait()
