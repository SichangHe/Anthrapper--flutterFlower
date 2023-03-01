import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

import '../transport_protos.dart';

class FlowerBase {
  ClientMessage weightsAsProto(List<Uint8List> weights) {
    Parameters p = Parameters()
      ..tensors.addAll(weights)
      ..tensorType = "ND";
    ClientMessage_GetParametersRes res = ClientMessage_GetParametersRes()
      ..parameters = p;
    return ClientMessage()..getParametersRes = res;
  }

  ClientMessage fitResAsProto(List<Uint8List> weights, int trainingSize) {
    Parameters p = Parameters()
      ..tensors.addAll(weights)
      ..tensorType = 'ND';
    ClientMessage_FitRes res = ClientMessage_FitRes()
      ..parameters = p
      ..numExamples = Int64(trainingSize);
    return ClientMessage()..fitRes = res;
  }

  ClientMessage evaluateResAsProto(double accuracy, int testingSize) {
    ClientMessage_EvaluateRes res = ClientMessage_EvaluateRes()
      ..loss = accuracy
      ..numExamples = Int64(testingSize);
    return ClientMessage()..evaluateRes = res;
  }
}
