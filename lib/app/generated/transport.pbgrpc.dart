///
//  Generated code. Do not modify.
//  source: transport.proto
//
// @dart = 2.12
// ignore_for_file: annotate_overrides,camel_case_types,constant_identifier_names,directives_ordering,library_prefixes,non_constant_identifier_names,prefer_final_fields,return_of_invalid_type,unnecessary_const,unnecessary_import,unnecessary_this,unused_import,unused_shown_name

import 'dart:async' as $async;

import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'transport.pb.dart' as $0;
export 'transport.pb.dart';

class FlowerServiceClient extends $grpc.Client {
  static final _$join = $grpc.ClientMethod<$0.ClientMessage, $0.ServerMessage>(
      '/flwr.proto.FlowerService/Join',
      ($0.ClientMessage value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ServerMessage.fromBuffer(value));

  FlowerServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  $grpc.ResponseStream<$0.ServerMessage> join(
      $async.Stream<$0.ClientMessage> request,
      {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$join, request, options: options);
  }
}

abstract class FlowerServiceBase extends $grpc.Service {
  $core.String get $name => 'flwr.proto.FlowerService';

  FlowerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ClientMessage, $0.ServerMessage>(
        'Join',
        join,
        true,
        true,
        ($core.List<$core.int> value) => $0.ClientMessage.fromBuffer(value),
        ($0.ServerMessage value) => value.writeToBuffer()));
  }

  $async.Stream<$0.ServerMessage> join(
      $grpc.ServiceCall call, $async.Stream<$0.ClientMessage> request);
}
