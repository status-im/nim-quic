import unittest
import sequtils
import math
import quic
import quic/bits
import stew/endians2

suite "packet writing":

  var datagram: seq[byte]

  setup:
    datagram = newSeq[byte](4096)

  test "writes short/long form":
    datagram.write(Packet(form: formShort))
    check datagram[0].bits[0] == 0
    datagram.write(Packet(form: formLong))
    check datagram[0].bits[0] == 1

  test "writes fixed bit":
    datagram.write(Packet(form: formShort))
    check datagram[0].bits[1] == 1
    datagram.write(Packet(form: formLong))
    check datagram[0].bits[1] == 1

  test "writes packet type":
    datagram.write(Packet(form: formLong, kind: packetInitial))
    check datagram[0] == 0b11000000
    datagram.write(Packet(form: formLong, kind: packet0RTT))
    check datagram[0] == 0b11010000
    datagram.write(Packet(form: formLong, kind: packetHandshake))
    check datagram[0] == 0b11100000
    datagram.write(Packet(form: formLong, kind: packetRetry))
    check datagram[0] == 0b11110000

  test "writes version":
    var packet = Packet(form: formLong)
    packet.version = 0xAABBCCDD'u32
    datagram.write(packet)
    check datagram[1..4] == @[0xAA'u8, 0xBB'u8, 0xCC'u8, 0xDD'u8]

  test "writes source and destination":
    const source = @[1'u8, 2'u8]
    const destination = @[3'u8, 4'u8, 5'u8]
    var packet = Packet(form: formLong)
    packet.source = ConnectionId(source)
    packet.destination = ConnectionId(destination)
    datagram.write(packet)
    check datagram[5] == destination.len.uint8
    check datagram[6..8] == destination
    check datagram[9] == source.len.uint8
    check datagram[10..11] == source

  test "writes supported version for a version negotiation packet":
    const supportedVersion = 0xAABBCCDD'u32
    var packet = Packet(form: formLong, kind: packetVersionNegotiation)
    packet.negotiation.supportedVersion = supportedVersion
    datagram.write(packet)
    check datagram[7..10] == supportedVersion.toBytesBE

suite "packet reading":

  var datagram: seq[byte]

  setup:
    datagram = newSeq[byte](4096)

  test "reads long/short form":
    datagram[0] = 0b01000000
    check readPacket(datagram).form == formShort
    datagram[0] = 0b11000000
    check readPacket(datagram).form == formLong

  test "checks fixed bit":
    datagram[0] = 0b00000000
    expect Exception:
      discard readPacket(datagram)

  test "reads packet type":
    const version = 1'u32
    datagram[1..4] = version.toBytesBE
    datagram[0] = 0b11000000
    check readPacket(datagram).kind == packetInitial
    datagram[0] = 0b11010000
    check readPacket(datagram).kind == packet0RTT
    datagram[0] = 0b11100000
    check readPacket(datagram).kind == packetHandshake
    datagram[0] = 0b11110000
    check readPacket(datagram).kind == packetRetry

  test "reads version negotiation packet":
    const version = 0'u32
    datagram[0] = 0b11000000
    datagram[1..4] = version.toBytesBE
    check readPacket(datagram).kind == packetVersionNegotiation

  test "reads version":
    const version = 0xAABBCCDD'u32
    datagram[0] = 0b11000000
    datagram[1..4] = version.toBytesBE
    check readPacket(datagram).version == version

  test "reads source and destination connection id":
    const source = @[1'u8, 2'u8, 3'u8]
    const destination = @[4'u8, 5'u8, 6'u8]
    datagram[0] = 0b11000000
    datagram[5] = destination.len.uint8
    datagram[6..8] = destination
    datagram[9] = source.len.uint8
    datagram[10..12] = source
    let packet = readPacket(datagram)
    check packet.source == ConnectionId(source)
    check packet.destination == ConnectionId(destination)

  test "reads supported version in version negotiation packet":
    const supportedVersion = 0xAABBCCDD'u32
    const version = 0'u32
    datagram[0] = 0b11000000
    datagram[1..4] = version.toBytesBE
    datagram[7..10] = supportedVersion.toBytesBE
    check readPacket(datagram).negotiation.supportedVersion == supportedVersion

suite "packet length":

  const destination = ConnectionId(@[3'u8, 4'u8, 5'u8])
  const source = ConnectionId(@[1'u8, 2'u8])
  const token = @[0xA'u8, 0xB'u8, 0xC'u8]

  test "knows the length of a version negotiation packet":
    var packet = Packet(form: formLong, kind: packetVersionNegotiation)
    packet.destination = destination
    packet.source = source
    packet.negotiation.supportedVersion = 42
    check packet.len == 11 + destination.len + source.len

  test "knows the length of a retry packet":
    var packet = Packet(form: formLong, kind: packetRetry)
    packet.destination = destination
    packet.source = source
    packet.retry.token = token
    packet.retry.integrity[0..15] = repeat(0xA'u8, 16)
    check packet.len == 7 + destination.len + source.len + token.len + 16

suite "packet numbers":

  test "packet numbers are in the range 0 to 2^62-1":
    check PacketNumber.low == 0
    check PacketNumber.high == 2'u64 ^ 62 - 1
