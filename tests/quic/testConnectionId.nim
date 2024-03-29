import pkg/unittest2
import pkg/quic/transport/connectionid

suite "connection ids":

  test "generates random ids":
    check randomConnectionId() != randomConnectionId()

  test "random ids are of the correct length":
    check randomConnectionId().len == DefaultConnectionIdLength

  test "random ids can have custom length":
    check randomConnectionId(5).len == 5
