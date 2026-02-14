abstract class IAiService {
  Future<String> sendMessage(String message);
  Stream<String> streamResponse(String message);
}
