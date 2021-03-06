import pkg/ngtcp2

proc defaultSettings*: ngtcp2_settings =
  ngtcp2_settings_default(addr result)
  result.transport_params.initial_max_streams_uni = 128
  result.transport_params.initial_max_stream_data_uni = 256 * 1024
  result.transport_params.initial_max_streams_bidi = 128
  result.transport_params.initial_max_stream_data_bidi_local = 256 * 1024
  result.transport_params.initial_max_stream_data_bidi_remote = 256 * 1024
  result.transport_params.initial_max_data = 256 * 1024
