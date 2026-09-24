class ServerUrl {
  static const String local =
      'http://172.16.163.2:81/pcount_app/pcount_local_james/';

  static const String live = 'http://172.16.163.2:81/pcount_app/pcount_live/';

  static Map<String, String> servers = {
    'LOCAL': local,
    'LIVE': live,
  };

  static String current = local;

  static void setServer(String server) {
    current = servers[server] ?? local;
  }
}
