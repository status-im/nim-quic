import pkg/chronos
import ../../../udp/datagram
import ../../quicconnection
import ../../connectionid
import ../../stream
import ../connection
import ../streams
import ./closingstate
import ./drainingstate
import ./disconnectingstate

type
  OpenConnection* = ref object of ConnectionState
    quicConnection: QuicConnection
    ngtcp2Connection: Ngtcp2Connection

proc newOpenConnection*(ngtcp2Connection: Ngtcp2Connection): OpenConnection =
  OpenConnection(ngtcp2Connection: ngtcp2Connection)

{.push locks: "unknown".}

method enter(state: OpenConnection, connection: QuicConnection) =
  procCall enter(ConnectionState(state), connection)
  state.quicConnection = connection

method leave(state: OpenConnection) =
  procCall leave(ConnectionState(state))
  state.ngtcp2Connection.destroy()
  state.quicConnection = nil

method ids(state: OpenConnection): seq[ConnectionId] =
  state.ngtcp2Connection.ids

method send(state: OpenConnection) =
  state.ngtcp2Connection.send()

method receive(state: OpenConnection, datagram: Datagram) =
  state.ngtcp2Connection.receive(datagram)
  if state.ngtcp2Connection.isDraining:
    let duration = state.ngtcp2Connection.closingDuration()
    let ids = state.ids
    let draining = newDrainingConnection(ids, duration)
    state.quicConnection.switch(draining)
    asyncSpawn draining.close()

method openStream(state: OpenConnection): Future[Stream] {.async.} =
  await state.quicConnection.handshake.wait()
  result = state.ngtcp2Connection.openStream()

method close(state: OpenConnection) {.async.} =
  let finalDatagram = state.ngtcp2Connection.close()
  let duration = state.ngtcp2Connection.closingDuration()
  let ids = state.ids
  let closing = newClosingConnection(finalDatagram, ids, duration)
  state.quicConnection.switch(closing)
  await closing.close()

method drop(state: OpenConnection) {.async.} =
  let disconnecting = newDisconnectingConnection(state.ids)
  state.quicConnection.switch(disconnecting)
  await disconnecting.drop()

method `onNewId=`*(state: OpenConnection, callback: IdCallback) =
  state.ngtcp2Connection.onNewId = callback

method `onRemoveId=`*(state: OpenConnection, callback: IdCallback) =
  state.ngtcp2Connection.onRemoveId = callback

{.pop.}