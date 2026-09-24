class ServerUrlList {
  //--------------------------> Note: Local IP should the same with the default IP @ server_url.dart<----------------------
  static var _serverUrlList = {
    'LOCAL': 'http://172.16.163.2:81/pcount_app/pcount_local_james/',
    'ASC: MAIN': 'http://172.16.163.2:81/pcount_app/pcount_alturas/',
    'ALTURAS TALIBON': 'http://172.16.163.2:81/pcount_app/pcount_alturas_talibon/',
    'ISLAND CITY MALL': 'http://172.16.163.2:81/pcount_app/pcount/',
    'ALTA CITTA': 'http://172.16.163.2:81/pcount_app/pcount_alta/',
    'DISTRIBUTION': 'http://172.16.163.2:81/pcount_app/pcount_pdc/',
    'URC': 'http://172.16.163.2:81/pcount_app/pcount_urc/',
    'PLAZA MARCELA': 'http://172.16.163.2:81/pcount_app/pcount_pm/',
    'GLASS SERVICE': 'http://172.16.163.2:81/pcount_app/pcount_local_james/'
    // 'WHOLESALE DISTRIBUTION GROUP'              : 'http://172.16.163.2:81/pcount_app/pcount_warehouse/',
    // 'UBAY DISTRIBUTION CENTER'                  : 'http://172.16.163.2:81/pcount_app/pcount_warehouse/',
    // 'TUBIGON'                                   : 'http://172.16.163.2:81/pcount_app/pcount_warehouse/',
    // 'JAGNA'                                     : 'http://172.16.163.2:81/pcount_app/pcount_warehouse/'
  };

  serverUrlKey() => _serverUrlList.entries.map((e) => e.key).toList();
  // serverUrlValue()=> _serverUrlList.entries.map((e) => e.value).toList();
  ip(String serverName) =>
      _serverUrlList['$serverName'] ?? 'Not found'.toString();
  //ip(String serverName)=>  _serverUrlList.values.firstWhere((e) => _serverUrlList[e] == serverName, orElse: () => "Not found");
  // server(String ip)=> _serverUrlList.keys.firstWhere((e) => _serverUrlList[e] == ip, orElse: () => "Not found");
}
